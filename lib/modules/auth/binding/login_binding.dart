import 'package:get/get.dart';

import '../../../data/services/auth_service.dart';
import '../viewmodel/login_viewmodel.dart';

/// DI da rota de login (regra 3: um binding por feature).
class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoginViewModel>(() => LoginViewModel(Get.find<AuthService>()));
  }
}
