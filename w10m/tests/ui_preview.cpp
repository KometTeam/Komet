#define wWinMain KometProductionMain
#include "../app/App.cpp"
#undef wWinMain

int __stdcall wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    init_apartment(apartment_type::multi_threaded);
    Application::Start([](auto const&) {
        auto app = make_self<komet::App>();
        DispatcherTimer setup;
        setup.Interval(std::chrono::seconds(1));
        setup.Tick([app, setup](auto const&, auto const&) {
            setup.Stop();
            app->timer_.Stop();
            ++app->generation_;
            if (app->session_) app->session_->Close();
            app->session_.reset();
            app->online_ = false;
            app->token_ = "synthetic-preview";
            app->me_ = 1001;
            app->contacts_ = {{"1002", {{"id", 1002}, {"names", komet::Json::array({{{"name", "Тестовый собеседник"}}})}}}};
            app->chats_ = komet::Json::array();
            for (int i = 1; i <= 18; ++i) {
                int64_t id = 2000 + i;
                app->chats_.push_back({{"id", id}, {"type", "CHAT"}, {"title", i == 1 ? "Длинное название тестового чата для проверки вёрстки" : "Тестовый чат " + std::to_string(i)}, {"newMessages", i}, {"lastMessage", {{"text", "Пример текста для проверки списка чатов"}}}});
                auto rows = komet::Json::array();
                for (int j = 1; j <= 80; ++j) rows.push_back({{"id", j}, {"sender", j % 2 ? 1002 : 1001}, {"time", 1800000000000LL + j * 60000}, {"text", "Тестовое сообщение " + std::to_string(j) + (j % 5 == 0 ? " — длинный текст для проверки переноса строк и прокрутки истории сообщений на узком экране." : "")}});
                app->history_cache_[std::to_string(id)] = std::move(rows);
            }
            app->SetBusy(false);
            app->ShowChats();
            app->Status(L"Локальный макет · вымышленные данные");
        });
        setup.Start();
    });
    return 0;
}
