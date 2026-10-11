import 'account_service.dart';
import 'app_backend.dart';

class ProductKeyRedeemResult {
  final bool ok;
  final String code;
  final String message;
  final int daysAdded;
  final DateTime? newProUntil;
  final bool isLifetime;

  const ProductKeyRedeemResult({
    required this.ok,
    required this.code,
    required this.message,
    required this.daysAdded,
    required this.newProUntil,
    this.isLifetime = false,
  });

  factory ProductKeyRedeemResult.fromMap(Map<String, dynamic> data) {
    return ProductKeyRedeemResult(
      ok: data['ok'] == true,
      code: data['code']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      daysAdded: (data['days_added'] as num?)?.toInt() ?? 0,
      newProUntil: data['new_pro_until'] == null
          ? null
          : DateTime.tryParse(data['new_pro_until'].toString()),
      isLifetime: data['is_lifetime'] == true,
    );
  }
}

class ProductKeyService {
  ProductKeyService._();

  static Future<ProductKeyRedeemResult> redeem(String key) async {
    if (!AppBackend.configured) {
      throw StateError('Backend GamerLocker nao configurado.');
    }

    if (!AccountService.isLoggedIn) {
      throw StateError(
        'Entre na sua conta GamerLocker antes de ativar uma chave.',
      );
    }

    final response = await AppBackend.client.rpc(
      'redeem_product_key',
      params: {'p_key': key.trim().toUpperCase()},
    );

    Map<String, dynamic>? row;

    if (response is List && response.isNotEmpty) {
      row = Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map) {
      row = Map<String, dynamic>.from(response);
    }

    if (row == null) {
      throw StateError('O servidor nao retornou o resultado da ativacao.');
    }

    final result = ProductKeyRedeemResult.fromMap(row);

    if (result.ok) {
      await AccountService.refreshPlan();
    }

    return result;
  }
}
