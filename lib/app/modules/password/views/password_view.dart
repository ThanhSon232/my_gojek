import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:my_grab/app/themes/text.dart';

import '../../../routes/app_pages.dart';
import '../controllers/password_controller.dart';

class PasswordView extends GetView<PasswordController> {
  const PasswordView({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    const h = SizedBox(height: 10,);
    return GestureDetector(
      onTap: (){
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back, color: Colors.black,
            ), onPressed: () {
            Get.back();
          },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.info,
                  color: Colors.black,
                ),
              ),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.only(left: 10, right: 10, top: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You're almost there!",
                style: textTheme.headline1,
              ),
              h,
              const Text("You only have to enter a password in order to create an account in our system", style: normalBlackText,),
              h,
              Text("Password", style: textTheme.headline3,),
              Form(
                key: controller.formKey,
                child: TextFormField(
                  obscureText: true,
                  controller: controller.passwordController,
                  validator: (val) => controller.passwordValidator(val!),
                  decoration: const InputDecoration(
                  ),
                ),
              )
            ],
          ),
        ),
        floatingActionButton:  FloatingActionButton(
            elevation: 0.0,
            backgroundColor: Colors.grey,
            onPressed: () async {
              if(controller.check()){
                await controller.register();
                Get.offAllNamed(Routes.HOME);
              }

            },
            child: Obx(()=> controller.isLoading.value ? const CircularProgressIndicator(color: Colors.white,) : const Icon(
                Icons.arrow_forward,
                color: Colors.white,
              ),
            ))
      ),
    );
  }
}
