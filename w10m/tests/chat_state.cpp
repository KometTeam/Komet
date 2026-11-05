#include "../app/ChatState.h"
#include <iostream>

int main() {
    try {
        using namespace komet;
        Json saved = Json::array();
        EnsureSavedChat(saved); EnsureSavedChat(saved);
        if (saved.size() != 1 || Integer(saved[0], "id", -1) != 0) throw std::runtime_error("Saved chat missing or duplicated");
        if (!MergeReadMark(saved, {{"chatId", 0}, {"userId", 1001}, {"mark", 1}})) throw std::runtime_error("Zero chat ID rejected");
        Json message = {{"id", 10}, {"time", 500}, {"sender", 1001}};
        Json chats = Json::array({{{"id", 2001}, {"participants", {{"1001", 999}, {"1002", 499}}}}});
        if (ReadByOthers(chats[0], message, 1001)) throw std::runtime_error("Own receipt counted as peer");
        if (!MergeReadMark(chats, {{"chatId", 2001}, {"userId", 1002}, {"mark", 500}}) || !ReadByOthers(chats[0], message, 1001)) throw std::runtime_error("Receipt boundary failed");
        if (MergeReadMark(chats, {{"chatId", 2001}, {"userId", 1002}, {"mark", 400}})) throw std::runtime_error("Receipt regressed");
        if (MergeReadMark(chats, {{"chatId", 2001}, {"userId", 1002}, {"mark", 800}, {"setAsUnread", true}})) throw std::runtime_error("Unread flag counted");
        message["sender"] = 1002;
        if (ReadByOthers(chats[0], message, 1001)) throw std::runtime_error("Incoming message marked as outgoing receipt");
        auto first = Encode(1, 11, 19, {{"synthetic", true}});
        auto second = Encode(0, 12, 130, {{"mark", 500}});
        Bytes both = first; both.insert(both.end(), second.begin(), second.end());
        for (size_t split = 0; split <= both.size(); ++split) {
            Bytes pending(both.begin(), both.begin() + split);
            std::vector<Bytes> frames;
            for (;;) { auto frame = TakeFrame(pending); if (frame.empty()) break; frames.push_back(frame); }
            auto checkpoint = MsgReader(Json::to_msgpack(Json{{"seq", 99}, {"incoming", Json::binary(pending)}})).Decode();
            pending = checkpoint["incoming"].get_binary();
            pending.insert(pending.end(), both.begin() + split, both.end());
            for (;;) { auto frame = TakeFrame(pending); if (frame.empty()) break; frames.push_back(frame); }
            if (!pending.empty() || frames.size() != 2 || frames[0] != first || frames[1] != second) throw std::runtime_error("Socket transfer fragmentation lost data");
        }
        std::cout << "PASS: read receipts, monotonic marks, incoming-message exclusion, all partial-frame transfer boundaries\n";
        return 0;
    } catch (std::exception const& e) { std::cerr << e.what() << '\n'; return 1; }
}
