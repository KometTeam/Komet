#pragma once
#include "Protocol.h"

namespace komet {
inline void EnsureSavedChat(Json& chats) {
    if (!chats.is_array()) chats = Json::array();
    for (auto const& chat : chats) if (chat.contains("id") && Integer(chat, "id") == 0) return;
    chats.push_back({{"id", 0}, {"type", "DIALOG"}, {"title", "Избранное"}, {"participants", Json::object()}});
}
inline bool ReadByOthers(Json const& chat, Json const& message, int64_t me) {
    auto stamp = Integer(message, "time");
    if (stamp <= 0 || Integer(message, "sender") != me) return false;
    auto participants = Object(chat, "participants");
    for (auto it = participants.begin(); it != participants.end(); ++it) {
        if (it.key() == std::to_string(me)) continue;
        auto mark = it->is_number_integer() ? it->get<int64_t>() : it->is_object() ? Integer(*it, "mark") : Integer(Json{{"mark", *it}}, "mark");
        if (mark >= stamp) return true;
    }
    return false;
}
inline bool MergeReadMark(Json& chats, Json const& payload) {
    if (payload.value("setAsUnread", false)) return false;
    auto chat = Integer(payload, "chatId"), user = Integer(payload, "userId"), mark = Integer(payload, "mark");
    if (!payload.contains("chatId") || !user || mark <= 0) return false;
    for (auto& item : chats) if (Integer(item, "id") == chat) {
        auto participants = Object(item, "participants");
        auto key = std::to_string(user);
        if (Integer(participants, key.c_str()) >= mark) return false;
        participants[key] = mark;
        item["participants"] = participants;
        return true;
    }
    return false;
}
}
