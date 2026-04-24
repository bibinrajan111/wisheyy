class ShareService {
  String buildWishUrl(String wishId) {
    // In production, use your Firebase Hosting domain.
    return 'https://wisheyy.web.app/player/$wishId';
  }

  String buildWhatsAppText(String wishUrl) {
    return 'I made something special for you 💌\n$wishUrl';
  }
}
