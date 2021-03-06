import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_grab/app/data/common/api_handler.dart';
import 'package:my_grab/app/data/common/location.dart';
import 'package:my_grab/app/data/common/util.dart';
import 'package:my_grab/app/data/models/vehicle.dart';
import 'package:my_grab/app/modules/find_transportation/controllers/find_transportation_controller.dart';
import 'package:my_grab/app/modules/search_page/controllers/search_page_controller.dart';
import 'package:my_grab/app/modules/user/controllers/user_controller.dart';
import 'package:intl/intl.dart';

import '../../../data/common/network_handler.dart';
import '../../../data/common/search_location.dart';

class MapController extends GetxController {
  var id = 0;
  var findTransportationController = Get.find<FindTransportationController>();
  var searchPageController = Get.find<SearchPageController>();
  var userController = Get.find<UserController>();
  var address = ''.obs;
  late GoogleMapController googleMapController;
  var isLoading = false.obs;
  var isDragging = false.obs;
  var isShow = false;
  var pass = false.obs;
  Rx<STATUS> status = STATUS.SELECTVEHICLE.obs;
  RxString text = "Your current location".obs;
  var selectedIndex = 0.obs;

  List<Vehicle> vehicleList = [
    Vehicle(
        name: "Motorbike",
        type: "MOTORBIKE",
        price: "",
        duration: "",
        priceAfterVoucher: "",
        picture: "assets/vehicles/motorcycle.png",
        seatNumber: "2"),
    Vehicle(
        name: "Car4S",
        type: "CAR4S",
        price: "",
        duration: "",
        priceAfterVoucher: "",
        picture: "assets/vehicles/car.png",
        seatNumber: "4"),
    Vehicle(
        name: "Car7S",
        type: "CAR7S",
        price: "",
        duration: "",
        priceAfterVoucher: "",
        picture: "assets/vehicles/car.png",
        seatNumber: "7"),
    Vehicle(
        name: "Car16S",
        type: "CAR16S",
        price: "",
        duration: "",
        priceAfterVoucher: "",
        picture: "assets/vehicles/car.png",
        seatNumber: "16"),
  ];

  //search
  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
  RxList<LatLng> polylinePoints = <LatLng>[].obs;
  List<PointLatLng> searchResult = [];
  final RxList<Polyline> polyline = <Polyline>[].obs;
  SearchLocation? myLocation;
  SearchLocation? searchingLocation;
  TYPES? types;

  //controller
  Location? from;
  Location? to;

  APIHandlerImp apiHandlerImp = APIHandlerImp();

  Map<dynamic, dynamic> request = {};

  StreamSubscription? listener;
  StreamSubscription? listener1;

  @override
  void onInit() async {
    super.onInit();
    isLoading.value = true;

    await getCurrentPosition();

    from = Location(
        lat: findTransportationController.position["latitude"],
        lng: findTransportationController.position["longitude"]);

    await getAddress(from);

    to = Location(
        lat: findTransportationController.position["latitude"],
        lng: findTransportationController.position["longitude"]);

    polyline.add(Polyline(
      polylineId: const PolylineId('line1'),
      visible: true,
      points: polylinePoints,
      width: 5,
      color: Colors.blue,
    ));

    if (Get.arguments != null) {
      if (Get.arguments["type"] == SEARCHTYPES.LOCATION) {
        isShow = true;
        text.value = "Set pickup location";
        myLocation = Get.arguments["location"];
        await getAddress(myLocation!.location);
        await myLocationMarker("1", myLocation?.location,
            searchPageController.myLocationController);
        types = TYPES.SELECTLOCATION;
      } else {
        if (Get.arguments["location"] != null &&
            Get.arguments["destination"] == null) {
          isShow = true;
          from = Get.arguments["location"];
          text.value = "Set destination";
          await myLocationMarker(
              "2", to, searchPageController.destinationController);
          types = TYPES.SELECTEVIAMAP;
        } else {
          isShow = true;
          searchingLocation = Get.arguments["destination"];
          text.value = "Set pickup location";
          from = searchPageController.currentLocation;
          await myLocationMarker(
              "1", from, searchPageController.myLocationController);
          types = TYPES.SELECTDESTINATION;
        }
      }
    }

    isLoading.value = false;
  }

  getCurrentPosition() async {
    findTransportationController.position.value =
        await findTransportationController.map.getCurrentPosition();
  }

  getAddress(Location? location) async {
    var temp = await findTransportationController.map
        .getCurrentAddress(location?.lat!, location?.lng!);
    address.value =
        "${temp.name} ${temp.subLocality} ${temp.subAdministrativeArea} ${temp.locality}  ${temp.country}";
    location?.address = address.value;
  }

  myLocationMarker(String id, Location? l, TextEditingController t) async {
    await getAddress(l);
    t.text = address.value;
    final Marker marker = Marker(
        markerId: MarkerId(id),
        draggable: true,
        onDrag: (position) {
          isDragging.value = true;
        },
        icon: id == "2"
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onDragEnd: ((newPosition) async {
          isDragging.value = false;
          l?.setLocation(newPosition);
          await getAddress(l);
          t.text = address.value;
        }),
        position: LatLng(
            l?.lat ?? findTransportationController.map.position.latitude,
            l?.lng ?? findTransportationController.map.position.longitude));
    googleMapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(l!.lat!, l!.lng!), zoom: 15),
    ));
    markers[MarkerId(id)] = marker;
  }

  route(Location? from, Location? to) async {
    EasyLoading.show();

    polylinePoints.clear();
    var start = "${from?.lat},${from?.lng}";
    var end = "${to?.lat},${to?.lng}";
    Map<String, String> query = {
      "key": "d2c643ad1e2975f1fa0d1719903704e8",
      "origin": start,
      "destination": end,
      "mode": selectedIndex.value == 0 ? "motorcycle" : "car"
    };

    isLoading.value = true;
    var response = await NetworkHandler.getWithQuery('route', query);
    searchResult = PolylinePoints()
        .decodePolyline(response["result"]["routes"][0]["overviewPolyline"]);
    for (var point in searchResult) {
      polylinePoints.add(LatLng(point.latitude, point.longitude));
    }
    polyline.refresh();

    var response1 = await apiHandlerImp.put({
      "distance": response["result"]["routes"][0]["legs"][0]["distance"]
              ["value"] /
          1000,
      "timeSecond": response["result"]["routes"][0]["legs"][0]["duration"]
          ["value"],
    }, "user/getVehicleAndPrice");

    for (int i = 0;
        i < response1.data["data"]["vehiclesAndPrices"].length;
        i++) {
      vehicleList[i].price =
          response1.data["data"]["vehiclesAndPrices"][i]["price"].toString();
      vehicleList[i].duration = response["result"]["routes"][0]["legs"][0]
              ["duration"]["text"]
          .toString()
          .replaceFirst("ph??t", "m")
          .replaceFirst("gi???", "h")
          .replaceFirst("gi??y", "s");
    }

    request["distance"] =
        response["result"]["routes"][0]["legs"][0]["distance"]["value"] / 1000;
    request["timeSecond"] =
        response["result"]["routes"][0]["legs"][0]["duration"]["value"];

    isLoading.value = false;
    EasyLoading.dismiss();
  }

  void dragPosition(MarkerId markerId, CameraPosition position) {
    LatLng newMarkerPosition =
        LatLng(position.target.latitude, position.target.longitude);
    markers[markerId] = Marker(markerId: markerId, position: newMarkerPosition);
  }

  void handleSearch() async {
    if (types == TYPES.SELECTLOCATION) {
      text.value = "Set pickup location";
      searchPageController.currentLocation = myLocation!.location!;
      searchPageController.myLocationController.text = address.value;
      searchPageController.location.clear();
      Get.back();
    } else if (types == TYPES.SELECTDESTINATION) {
      text.value = "Set up destination";
      await myLocationMarker("2", searchingLocation?.location,
          searchPageController.destinationController);
      to = searchingLocation?.location;
      types = TYPES.HASBOTH;
    } else if (types == TYPES.SELECTEVIAMAP) {
      text.value = "Set pickup location";
      await myLocationMarker(
          "1", from, searchPageController.myLocationController);
      types = TYPES.HASBOTH;
    } else if (types == TYPES.HASBOTH) {
      route(from, to);
      pass.value = true;
      googleMapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
            target: LatLng(
                (from!.lat! + to!.lat!) / 2, (from!.lng! + to!.lng!) / 2),
            zoom: 12.5),
      ));
    }
  }

  Future<void> handleMyLocationButton() async {
    await getCurrentPosition();
    googleMapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
            target: LatLng(findTransportationController.position["latitude"],
                findTransportationController.position["longitude"]),
            zoom: 15),
      ),
    );
  }

  Future<void> bookingCar() async {
    EasyLoading.show();
    isLoading.value = true;

    // await apiHandlerImp.put({
    //   "startAddress": {
    //     "address": from?.address,
    //     "longitude": from?.lng,
    //     "latitude": from?.lat
    //   },
    //   "destination": {
    //     "address": to?.address,
    //     "longitude": to?.lng,
    //     "latitude": to?.lat
    //   },
    //   "vehicleAndPrice": {
    //     "vehicleType": vehicleList[selectedIndex.value].type,
    //     "price": vehicleList[selectedIndex.value].price
    //   },
    //   "createdTime":
    //       DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now().toLocal()),
    //   "distanceAndTime": {
    //     "distance": request["distance"],
    //     "timeSecond": request["timeSecond"],
    //   },
    //   "discountId": "",
    //   "note": ""
    // }, "user/${userController.user!.id}/booking");
    Random random = Random();
    int randomNumber = random.nextInt(100);
    isLoading.value = false;
    // await FirebaseDatabase.instance
    //     .ref(
    //         "${vehicleList[selectedIndex.value].type}/${double.parse(10.768709.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/${double.parse(106.667423.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/driverList")
    //     .child(randomNumber.toString())
    //     .set({
    //   "startAddress": {
    //     "address": from?.address,
    //     "longitude": from?.lng,
    //     "latitude": from?.lat
    //   },
    //   "destination": {
    //     "address": to?.address,
    //     "longitude": to?.lng,
    //     "latitude": to?.lat
    //   },
    //   "vehicleAndPrice": {
    //     "vehicleType": vehicleList[selectedIndex.value].type,
    //     "price": vehicleList[selectedIndex.value].price
    //   },
    //   "user": userController.user!.toJson(),
    //   "createdTime":
    //       DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now().toLocal()),
    //   "distanceAndTime": {
    //     "distance": request["distance"],
    //     "timeSecond": request["timeSecond"],
    //   },
    //   "discountId": "",
    //   "note": ""
    // });
    showSnackBar("?????t xe th??nh c??ng", "?????i t?? c?? ng?????i ????n li???n");
    EasyLoading.dismiss();

    await FirebaseDatabase.instance
        .ref(
            "${vehicleList[selectedIndex.value].type}/${double.parse(10.768709.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/${double.parse(106.667423.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/request")
        .child(userController.user!.id.toString())
        .set({
      "startAddress": {
        "address": from?.address,
        "longitude": from?.lng,
        "latitude": from?.lat
      },
      "destination": {
        "address": to?.address,
        "longitude": to?.lng,
        "latitude": to?.lat
      },
      "vehicleAndPrice": {
        "vehicleType": vehicleList[selectedIndex.value].type,
        "price": vehicleList[selectedIndex.value].price
      },
      "user": userController.user!.toJson(),
      "createdTime":
          DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now().toLocal()),
      "distanceAndTime": {
        "distance": request["distance"],
        "timeSecond": request["timeSecond"],
      },
      "discountId": "",
      "note": ""
    });

    listener = FirebaseDatabase.instance
        .ref(
            "${vehicleList[selectedIndex.value].type}/${double.parse(10.768517.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/${double.parse(106.669975.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/request/")
        .limitToFirst(1)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.exists) {
        // showSnackBar("??ang c?? chuy???n", "??ang c?? chuy???n");
        print(event.snapshot.value);
      }
    });

    listener1 = FirebaseDatabase.instance
        .ref(
            "${vehicleList[selectedIndex.value].type}/${double.parse(10.768517.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/${double.parse(106.669975.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/request/${userController.user!.id.toString()}/driver")
        .limitToFirst(1)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.exists) {
        Get.defaultDialog(
          title: "GeeksforGeeks",
          middleText: "Hello world!",
          backgroundColor: Colors.green,
          titleStyle: const TextStyle(color: Colors.white),
          middleTextStyle: const TextStyle(color: Colors.white),
        );
      }
    });
  }

  Future<void> handleBackButton() async {
    Get.defaultDialog(
        middleText:
            "You might have to wait longer in next order if you cancel now. Do you still want to cancel?",
        backgroundColor: Colors.white,
        titleStyle: const TextStyle(color: Colors.black),
        middleTextStyle:
            const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        textConfirm: "Yes",
        onConfirm: () async {
          await cancelBooking();
          Get.close(1);
        },
        radius: 10,
        textCancel: "No, sir");
  }

  Future<void> cancelBooking() async {
    EasyLoading.show();
    isLoading.value = true;

    await apiHandlerImp.put({}, "user/cancelBooking/$id");

    await FirebaseDatabase.instance
        .ref(
            "${vehicleList[selectedIndex.value].type}/${double.parse(10.768517.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/${double.parse(106.669975.toString()).toStringAsFixed(2).replaceFirst(".", ",")}/request/${userController.user!.id.toString()}")
        .remove();
    showSnackBar("???? hu??? chuy???n", "???? hu??? chuy???n");
    isLoading.value = false;
    status.value = STATUS.SELECTVEHICLE;
    listener!.cancel();
    listener1!.cancel();
    EasyLoading.dismiss();
  }
}

enum TYPES { SELECTLOCATION, SELECTEVIAMAP, SELECTDESTINATION, HASBOTH }

enum STATUS { SELECTVEHICLE, FINDING, FOUND, CANCEL }
