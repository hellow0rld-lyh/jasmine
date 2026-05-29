import 'package:event/event.dart';
import '../basic/entities.dart';

var isPro = true;
var isProEx = 2147483646;

ProInfoAf? _proInfoAf;
ProInfoPat? _proInfoPat;

ProInfoAf get proInfoAf =>
    _proInfoAf ?? ProInfoAf.fromJson({"is_pro": true, "expire": 2147483646});
ProInfoPat get proInfoPat => _proInfoPat ??
    ProInfoPat.fromJson({
      "is_pro": true,
      "pat_id": "local",
      "bind_uid": "local",
      "request_delete": 0,
      "re_bind": 0,
      "error_type": 0,
      "error_msg": "",
      "access_key": "local"
    });

final proEvent = Event();

Future reloadIsPro() async {
  proEvent.broadcast();
}
