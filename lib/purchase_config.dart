class PurchaseConfig {
  PurchaseConfig._();

  static const String brandName = 'GamerLocker';

  static const String proPrice = 'R\$ 29,90 / mes';

  static const String discordContact = 'dippo8291';

  static bool get hasDiscordConfigured =>
      discordContact != 'SEU_DISCORD_AQUI' && discordContact.trim().isNotEmpty;
}
