part of 'api_service.dart';

extension ApiServiceComplaints on ApiService {
  void getComplaints() {
    final payload = {"complainSync": 0};
    _sendMessage(162, payload);
  }

  void sendComplaint(int chatId, String messageId, int typeId, int reasonId) {
    final payload = {
      "reasonId": reasonId,
      "parentId": chatId,
      "typeId": 3,
      "ids": [int.parse(messageId)], 
    };
    _sendMessage(161, payload);
  }
}
