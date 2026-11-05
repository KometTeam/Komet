    void Dialog(hstring const& title, IInspectable const& body, std::function<void()> accept, hstring const& button = L"Готово") {
        ContentDialog dialog;
        dialog.Title(box_value(title));
        dialog.Content(body);
        dialog.PrimaryButtonText(button);
        dialog.SecondaryButtonText(L"Отмена");
        auto self = get_strong();
        auto dispatcher = Window::Current().Dispatcher();
        dialog.ShowAsync().Completed([self, dispatcher, accept](auto const& operation, auto state) {
            if (state != Windows::Foundation::AsyncStatus::Completed || operation.GetResults() != ContentDialogResult::Primary) return;
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, accept] {
                try { accept(); }
                catch (hresult_error const& error) { self->Status(error.message()); }
                catch (std::exception const& error) { self->Status(to_hstring(error.what())); }
            });
        });
    }

    void Form(hstring const& title, std::vector<hstring> const& names, std::function<void(std::vector<std::string>)> accept,
              std::vector<hstring> const& initial = {}) {
        StackPanel panel;
        std::vector<TextBox> inputs;
        for (size_t i = 0; i < names.size(); ++i) {
            TextBox input;
            input.Header(box_value(names[i]));
            input.Margin(Thickness{0, 4, 0, 8});
            input.MaxLength(4000);
            if (i < initial.size()) input.Text(initial[i]);
            panel.Children().Append(input);
            inputs.push_back(input);
        }
        Dialog(title, panel, [inputs, accept] {
            std::vector<std::string> values;
            for (auto const& input : inputs) values.push_back(to_string(input.Text()));
            accept(values);
        });
    }

    StackPanel ToolsPanel(hstring const& title) {
        PageStart(Page::Tools, title);
        StackPanel panel;
        panel.Margin(Thickness{16, 8, 16, 20});
        ScrollViewer scroll;
        scroll.Content(panel);
        content_.Children().Append(scroll);
        return panel;
    }

    void Action(uint16_t opcode, Json payload, hstring const& message = L"Изменения сохранены", bool history = false) {
        if (!online_ || !session_) { Status(L"Сначала подключитесь к MAX."); return; }
        Run([opcode, payload](auto session) { return session->Request(opcode, payload); },
            [this, message, history](Json) {
                Status(message);
                if (history && (page_ == Page::Conversation || tools_return_conversation_)) { ShowConversation(); LoadHistory(false); }
            }, L"Выполнение…");
    }

    void RegisterAccount(std::string const& registration) {
        Form(L"Создание профиля MAX", {L"Имя", L"Фамилия"}, [this, registration](auto values) {
            if (values[0].empty()) { Status(L"Введите имя."); return; }
            Run([registration, values](auto session) {
                session->Request(23, {{"token", registration}, {"tokenType", "REGISTER"}, {"firstName", values[0]}, {"lastName", values[1]}});
                return session->Login(registration);
            }, [this, registration](Json data) { token_ = registration; ApplyLogin(data); }, L"Создание профиля…");
        });
    }

    void ApplyProfile(Json const& data, Json const& fallback = Json::object()) {
        auto profile = Object(data, "profile");
        if (profile.empty()) profile = data;
        auto contact = Object(profile, "contact");
        if (contact.empty() && profile.contains("names")) contact = profile;
        if (contact.empty()) contact = Object(profile_, "contact");
        if (contact.empty() && contacts_.contains(std::to_string(me_))) contact = contacts_.at(std::to_string(me_));
        for (auto key : {"baseUrl", "iconUrl"}) if (profile.contains(key)) contact[key] = profile.at(key);
        if (fallback.contains("firstName")) contact["names"] = Json::array({{{"type", "ONEME"}, {"firstName", fallback.at("firstName")}, {"lastName", fallback.value("lastName", "")}}});
        if (fallback.contains("description")) profile_["description"] = fallback.at("description");
        for (auto it = profile.begin(); it != profile.end(); ++it) profile_[it.key()] = it.value();
        if (!contact.empty()) {
            contact["id"] = me_;
            profile_["contact"] = contact;
            contacts_[std::to_string(me_)] = contact;
        }
        cache_dirty_ = true;
    }

    void SaveProfileFields(Json const& fields) {
        if (!RequireOnline([this, fields] { SaveProfileFields(fields); })) return;
        Run([fields](auto session) { return session->Request(16, fields); }, [this, fields](Json data) { ApplyProfile(data, fields); ShowProfile(); Status(L"Имя сохранено"); }, L"Сохранение профиля…");
    }

    void ShowProfile() {
        auto panel = ToolsPanel(L"Мой профиль");
        auto contact = Object(profile_, "contact");
        if (contact.empty() && contacts_.contains(std::to_string(me_))) contact = contacts_.at(std::to_string(me_));
        panel.Children().Append(Avatar(FirstText(contact, {"baseUrl", "iconUrl"}), to_hstring(ContactName(me_)), 112));
        panel.Children().Append(Label(to_hstring(ContactName(me_)), 24));
        auto phone = Integer(contact, "phone");
        if (phone) panel.Children().Append(Label(L"+" + to_hstring(phone)));
        auto description = Text(profile_, "description", Text(contact, "description"));
        if (!description.empty()) panel.Children().Append(Label(to_hstring(description)));
        panel.Children().Append(Label(L"Изменить профиль", 20));
        TextBox first;
        TextBox last;
        first.Header(box_value(L"Имя")); last.Header(box_value(L"Фамилия"));
        first.MaxLength(64); last.MaxLength(64);
        for (auto const& name : Array(contact, "names")) {
            if (Text(name, "type") == "ONEME" || first.Text().empty()) { first.Text(to_hstring(Text(name, "firstName", Text(name, "name")))); last.Text(to_hstring(Text(name, "lastName"))); }
        }
        panel.Children().Append(first); panel.Children().Append(last);
        panel.Children().Append(ButtonWith(L"Сохранить имя", [this, first, last] {
            if (first.Text().empty()) { Status(L"Введите имя."); return; }
            Json fields = {{"firstName", to_string(first.Text())}, {"lastName", to_string(last.Text())}};
            SaveProfileFields(fields);
        }));
        panel.Children().Append(ButtonWith(L"Выбрать фотографию профиля", [this] { PickPhoto(true); }));
        panel.Children().Append(ButtonWith(L"Устройства и сессии", [this] { ShowSessions(); }));
        panel.Children().Append(ButtonWith(L"Чёрный список", [this] { ShowBlocked(); }));
    }

    void ShowSessions() {
        Run([](auto session) { return session->Request(96, Json::object()); }, [this](Json data) {
            auto panel = ToolsPanel(L"Устройства");
            auto rows = Array(data, "sessions");
            if (rows.is_array()) for (auto const& item : rows) {
                auto name = Text(item, "deviceName", Text(Object(item, "userAgent"), "deviceName", "Устройство"));
                panel.Children().Append(Label(to_hstring(name), 20));
                panel.Children().Append(Label(to_hstring(Text(item, "osVersion") + "  " + Text(item, "appVersion"))));
            }
            panel.Children().Append(ButtonWith(L"Завершить другие сессии", [this] {
                Dialog(L"Завершить другие сессии?", box_value(L"На других устройствах понадобится повторный вход в MAX."),
                    [this] { Action(97, Json::object(), L"Другие сессии завершены"); }, L"Завершить");
            }));
        }, L"Загрузка устройств…");
    }

    void ResetAccountView() {
        ++generation_;
        SetBusy(false);
        if (session_) session_->Close();
        session_.reset();
        token_.clear();
        otp_token_.clear();
        track_.clear();
        qr_timer_.Stop();
        qr_track_.clear();
        me_ = 0;
        chat_ = 0;
        reply_id_ = 0;
        read_marks_.clear();
        marking_read_ = false;
        presence_ = Json::object();
        online_ = false;
        chats_ = Json::array();
        messages_ = Json::array();
        contacts_ = Json::object();
        history_cache_ = Json::object();
        drafts_.clear();
        profile_ = Json::object();
        cache_dirty_ = false;
        Cache::Invalidate();
    }

    void ShowAccounts() {
        auto panel = ToolsPanel(L"Аккаунты");
        auto values = Windows::Storage::ApplicationData::Current().LocalSettings().Values();
        try {
            for (auto const& credential : PasswordVault().FindAllByResource(L"KometW10M")) {
                auto name = credential.UserName();
                auto raw = to_string(name);
                if (raw.rfind("account:", 0) != 0) continue;
                auto id = std::stoll(raw.substr(8));
                auto key = L"name:" + to_hstring(id);
                auto title = values.HasKey(key) ? unbox_value<hstring>(values.Lookup(key)) : to_hstring(id);
                if (id == me_) title = title + L" · текущий";
                panel.Children().Append(ButtonWith(title, [this, name, id] {
                    auto saved = PasswordVault().Retrieve(L"KometW10M", name);
                    saved.RetrievePassword();
                    auto token = to_string(saved.Password());
                    auto values = Windows::Storage::ApplicationData::Current().LocalSettings().Values();
                    auto key = L"transport:" + to_hstring(id);
                    auto native = !values.HasKey(key) || unbox_value<bool>(values.Lookup(key));
                    ResetAccountView();
                    token_ = token;
                    native_mode_ = native;
                    ShowLogin();
                    Connect();
                }));
            }
        } catch (hresult_error const& error) {
            if (error.code() != HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) throw;
        }
        panel.Children().Append(ButtonWith(L"Добавить аккаунт", [this] { ResetAccountView(); native_mode_ = true; ShowLogin(); Status(L"Введите номер нового аккаунта или используйте QR-вход."); }));
    }

    void ShowCallHistory() {
        if (!online_) { Status(L"Сначала подключитесь к MAX."); return; }
        Run([](auto session) { return session->Request(79, Json::object()); }, [this](Json data) {
            auto panel = ToolsPanel(L"История звонков");
            panel.Children().Append(Label(L"Голосовые и видеозвонки ещё не поддерживаются этой сборкой W10M."));
            auto history = Array(data, "history");
            if (!history.is_array() || history.empty()) { panel.Children().Append(Label(L"История пуста.")); return; }
            for (auto const& entry : history) {
                auto message = Object(entry, "message");
                auto sender = Integer(message, "sender");
                auto label = sender == me_ ? L"Исходящий звонок" : L"Входящий: " + to_hstring(ContactName(sender));
                panel.Children().Append(Label(label, 18));
            }
        }, L"Загрузка истории звонков…");
    }

    void ShowContacts() {
        auto panel = ToolsPanel(L"Контакты");
        panel.Children().Append(ButtonWith(L"Найти по номеру телефона", [this] {
            Form(L"Поиск контакта", {L"Номер с кодом страны"}, [this](auto values) {
                auto phone = NormalizePhone(values[0]);
                Run([phone](auto session) { return session->Request(46, {{"phone", phone}}); }, [this](Json data) {
                    auto contact = Object(data, "contact");
                    auto id = Integer(contact, "id");
                    if (!id) { Status(L"Контакт не найден."); return; }
                    contacts_[std::to_string(id)] = contact;
                    ContactDetails(id);
                }, L"Поиск контакта…");
            });
        }));
        for (auto it = contacts_.begin(); it != contacts_.end(); ++it) {
            auto id = Integer(it.value(), "id");
            if (!id || id == me_) continue;
            panel.Children().Append(ButtonWith(to_hstring(ContactName(id)), [this, id] { ContactDetails(id); }));
        }
    }

    void ContactDetails(int64_t id) {
        auto panel = ToolsPanel(to_hstring(ContactName(id)));
        auto it = contacts_.find(std::to_string(id));
        auto contact = it != contacts_.end() ? *it : Json::object();
        auto avatar_url = FirstText(contact, {"baseUrl", "iconUrl"});
        if (!avatar_url.empty()) {
            Image avatar;
            avatar.Width(120);
            avatar.Height(120);
            avatar.Margin(Thickness{0, 8, 0, 12});
            ApplyImageSource(avatar, avatar_url, 240);
            panel.Children().Append(avatar);
        }
        auto presence = PresenceText(id);
        if (!presence.empty()) {
            auto line = Label(to_hstring(presence), 16);
            line.Foreground(ResourceBrush(L"SystemControlForegroundAccentBrush"));
            panel.Children().Append(line);
        }
        auto phone = Integer(contact, "phone");
        if (phone) panel.Children().Append(Label(L"+" + to_hstring(std::to_string(phone))));
        panel.Children().Append(Label(L"ID: " + to_hstring(std::to_string(id))));
        panel.Children().Append(ButtonWith(L"Написать сообщение", [this, id] {
            chat_ = me_ ^ id;
            auto found = std::find_if(chats_.begin(), chats_.end(), [this](Json const& item) { return Integer(item, "id") == chat_; });
            if (found == chats_.end()) chats_.push_back({{"id", chat_}, {"type", "DIALOG"}, {"title", ContactName(id)}});
            ShowConversation();
            LoadHistory(false);
        }));
        panel.Children().Append(ButtonWith(L"Добавить в контакты", [this, id] {
            Form(L"Добавление контакта", {L"Имя"}, [this, id](auto values) { Action(34, {{"action", "ADD"}, {"contactId", id}, {"firstName", values[0]}}, L"Контакт добавлен"); });
        }));
        panel.Children().Append(ButtonWith(L"Заблокировать", [this, id] {
            Dialog(L"Заблокировать контакт?", box_value(to_hstring(ContactName(id))),
                [this, id] { Action(34, {{"action", "BLOCK"}, {"contactId", id}}, L"Контакт заблокирован"); }, L"Заблокировать");
        }));
    }

    void ShowBlocked() {
        Run([](auto session) { return session->Request(36, {{"status", "BLOCKED"}, {"count", 100}, {"from", 0}}); }, [this](Json data) {
            auto panel = ToolsPanel(L"Чёрный список");
            auto rows = Array(data, "contacts");
            if (!rows.is_array() || rows.empty()) panel.Children().Append(Label(L"Заблокированных контактов нет."));
            else for (auto const& item : rows) {
                auto id = Integer(item, "id");
                contacts_[std::to_string(id)] = item;
                panel.Children().Append(ButtonWith(L"Разблокировать: " + to_hstring(ContactName(id)), [this, id] {
                    Action(34, {{"action", "UNBLOCK"}, {"contactId", id}}, L"Контакт разблокирован");
                }));
            }
        }, L"Загрузка списка…");
    }

    void ShowSettings() {
        auto panel = ToolsPanel(L"Настройки");
        panel.Children().Append(Label(L"Фон и уведомления", 24));
        auto values = Windows::Storage::ApplicationData::Current().LocalSettings().Values();
        CheckBox background;
        background.Content(box_value(L"Получать сообщения в фоне"));
        background.IsChecked(BackgroundEnabled());
        background.Click([this, background](auto const&, auto const&) {
            auto enabled = background.IsChecked().Value();
            Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"backgroundEnabled", box_value(enabled));
            if (enabled) SetupBackground(); else background_->Foreground();
        });
        panel.Children().Append(background);
        CheckBox notifications;
        notifications.Content(box_value(L"Показывать уведомления о сообщениях"));
        notifications.IsChecked(!values.HasKey(L"notificationsEnabled") || unbox_value<bool>(values.Lookup(L"notificationsEnabled")));
        notifications.Click([notifications](auto const&, auto const&) { Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"notificationsEnabled", box_value(notifications.IsChecked().Value())); });
        panel.Children().Append(notifications);
        CheckBox preview;
        preview.Content(box_value(L"Показывать текст в уведомлениях"));
        preview.IsChecked(!values.HasKey(L"notificationPreview") || unbox_value<bool>(values.Lookup(L"notificationPreview")));
        preview.Click([preview](auto const&, auto const&) { Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"notificationPreview", box_value(preview.IsChecked().Value())); });
        panel.Children().Append(preview);
        if (values.HasKey(L"lastImageError")) panel.Children().Append(Label(L"Последняя ошибка изображения: " + unbox_value<hstring>(values.Lookup(L"lastImageError")), 12));
        if (values.HasKey(L"backgroundStatus")) panel.Children().Append(Label(unbox_value<hstring>(values.Lookup(L"backgroundStatus")), 12));
        panel.Children().Append(ButtonWith(L"Повторить регистрацию фоновых задач", [this] { SetupBackground(); }));
        panel.Children().Append(Label(L"Windows может ограничивать фон при экономии заряда. Разрешение на фоновую работу задаётся в системных параметрах батареи.", 12));
        panel.Children().Append(Label(L"Совместимость", 24));
        panel.Children().Append(Label(L"Вход по коду использует профиль совместимости Komet: Android 14 / Samsung Galaxy S24 Ultra. QR-вход использует отдельную веб-сессию."));
        CheckBox ghost;
        ghost.Content(box_value(L"Не отправлять статус активности"));
        ghost.IsChecked(ghost_);
        ghost.Click([this, ghost](auto const&, auto const&) { ghost_ = ghost.IsChecked().Value(); SaveOptions(); });
        panel.Children().Append(ghost);
        CheckBox anti;
        anti.Content(box_value(L"Не отмечать сообщения прочитанными"));
        anti.IsChecked(anti_read_);
        anti.Click([this, anti](auto const&, auto const&) { anti_read_ = anti.IsChecked().Value(); SaveOptions(); });
        panel.Children().Append(anti);
        panel.Children().Append(ButtonWith(L"Включить превью push-уведомлений аккаунта", [this] {
            Action(22, {{"settings", {{"user", {{"PUSH_DETAILS", true}}}}}});
        }));
        panel.Children().Append(ButtonWith(L"Выключить превью push-уведомлений аккаунта", [this] {
            Action(22, {{"settings", {{"user", {{"PUSH_DETAILS", false}}}}}});
        }));
        panel.Children().Append(ButtonWith(L"Очистить сохранённую историю", [this] {
            Dialog(L"Очистить историю на телефоне?", box_value(L"Сообщения останутся на сервере MAX."), [this] {
                Run([](auto) { Cache::Clear(); return Json(nullptr); }, [this](Json) { history_cache_ = Json::object(); cache_dirty_ = false; Status(L"Локальная история удалена"); }, L"Очистка…");
            }, L"Очистить");
        }));
        panel.Children().Append(Label(L"Диагностика соединения", 24));
        panel.Children().Append(Label(L"Журнал последних событий связи: причина обрыва видна в строке «соединение потеряно» рядом."));
        if (conn_log_.empty()) panel.Children().Append(Label(L"Журнал пуст."));
        for (auto const& line : conn_log_) {
            auto row = Label(hstring(line), 12);
            row.IsTextSelectionEnabled(true);
            panel.Children().Append(row);
        }
        panel.Children().Append(Label(L"Системная тема и цвет берутся из Windows. Локальная история зашифрована средствами Windows и хранится в данных приложения."));
    }

    void SaveOptions() {
        auto values = Windows::Storage::ApplicationData::Current().LocalSettings().Values();
        values.Insert(L"ghost", box_value(ghost_));
        values.Insert(L"antiRead", box_value(anti_read_));
    }

    void ChooseChat(std::function<void(int64_t)> accept) {
        ListView list;
        list.MaxHeight(360);
        for (auto const& chat : chats_) {
            auto row = Label(to_hstring(ChatTitle(chat)), 18);
            row.Margin(Thickness{4, 10, 4, 10});
            row.Tag(box_value(Integer(chat, "id")));
            list.Items().Append(row);
        }
        Dialog(L"Выберите чат", list, [list, accept] {
            auto selected = list.SelectedItem();
            if (selected) accept(unbox_value<int64_t>(selected.as<FrameworkElement>().Tag()));
        });
    }

    void MessageMenu(FrameworkElement const& anchor, Json const& message) {
        if (busy_) return;
        auto id = Integer(message, "id");
        if (!id) return;
        auto chat = chat_;
        auto text = Text(message, "text");
        MenuFlyout menu;
        auto add = [&](hstring const& name, std::function<void()> action) {
            MenuFlyoutItem item;
            item.Text(name);
            item.Click([action](auto const&, auto const&) { action(); });
            menu.Items().Append(item);
        };
        Json viewerAttach;
        for (auto const& attach : Array(message, "attaches")) {
            auto type = Text(attach, "_type");
            if (type == "PHOTO" || type == "STICKER" || type == "VIDEO" || type == "AUDIO" || type == "FILE") { viewerAttach = attach; break; }
        }
        add(L"Ответить", [this, id, text] { reply_id_ = id; composer_.Header(box_value(L"Ответ на выбранное сообщение")); composer_.Focus(FocusState::Programmatic); });
        if (viewerAttach.is_object()) add(L"Открыть вложение", [this, chat, id, viewerAttach] { OpenAttachmentViewer(viewerAttach, chat, id); });
        if (!text.empty()) add(L"Копировать текст", [text] {
            Windows::ApplicationModel::DataTransfer::DataPackage data;
            data.SetText(to_hstring(text));
            Windows::ApplicationModel::DataTransfer::Clipboard::SetContent(data);
        });
        add(L"Переслать", [this, chat, id] {
            ChooseChat([this, chat, id](int64_t target) {
                Action(64, {{"chatId", target}, {"notify", true}, {"message", {{"cid", -Now()}, {"attaches", Json::array()}, {"elements", Json::array()},
                    {"link", {{"type", "FORWARD"}, {"chatId", chat}, {"messageId", id}}}}}}, L"Сообщение переслано");
            });
        });
        add(L"Реакция", [this, chat, id] {
            StackPanel panel;
            for (auto emoji : {L"👍", L"❤", L"😂", L"🔥", L"😢", L"👎"}) panel.Children().Append(ButtonWith(emoji, [this, chat, id, emoji] {
                Action(178, {{"chatId", chat}, {"messageId", id}, {"reaction", {{"reactionType", "EMOJI"}, {"id", to_string(emoji)}}}}, L"Реакция отправлена", true);
            }));
            Dialog(L"Реакция", panel, [] {}, L"Закрыть");
        });
        add(L"Убрать мою реакцию", [this, chat, id] { Action(179, {{"chatId", chat}, {"messageId", id}}, L"Реакция удалена", true); });
        if (Integer(message, "sender") == me_) add(L"Редактировать", [this, chat, id, text] {
            Form(L"Редактирование", {L"Текст"}, [this, chat, id](auto values) {
                Action(67, {{"chatId", chat}, {"messageId", id}, {"text", values[0]}, {"elements", Json::array()}}, L"Сообщение изменено", true);
            }, {to_hstring(text)});
        });
        add(L"Закрепить", [this, chat, id] { Action(55, {{"chatId", chat}, {"notifyPin", true}, {"pinMessageId", id}}, L"Сообщение закреплено"); });
        add(L"Удалить у меня", [this, chat, id] {
            Dialog(L"Удалить сообщение?", box_value(L"Сообщение будет удалено только у вас."), [this, chat, id] {
                Action(66, {{"chatId", chat}, {"messageIds", Json::array({id})}, {"forMe", true}, {"itemType", "REGULAR"}}, L"Сообщение удалено", true);
            }, L"Удалить");
        });
        if (Integer(message, "sender") == me_) add(L"Удалить у всех", [this, chat, id] {
            Dialog(L"Удалить у всех?", box_value(L"Сообщение будет удалено у участников чата."), [this, chat, id] {
                Action(66, {{"chatId", chat}, {"messageIds", Json::array({id})}, {"forMe", false}, {"itemType", "REGULAR"}}, L"Сообщение удалено", true);
            }, L"Удалить");
        });
        menu.ShowAt(anchor);
    }

    void RenderReactions(StackPanel const& body, Json const& message) {
        auto info = Object(message, "reactionInfo");
        auto rows = Array(info, "counters");
        if (!rows.is_array()) return;
        std::string text;
        for (auto const& row : rows) text += Text(row, "reaction") + " " + std::to_string(Integer(row, "count")) + "  ";
        if (!text.empty()) body.Children().Append(Label(to_hstring(text)));
    }

    void ApplyImageSource(Image const& image, std::string const& url, int width) {
        auto weak = get_weak();
        auto target = make_weak(image);
        LoadImage(url, {}, width, [weak, target](ImageSource const& source, hstring const& error) {
            if (auto image = target.get(); image && source) image.Source(source);
            if (!error.empty()) if (auto self = weak.get()) self->LogConn(L"Изображение: " + error);
        });
    }

    void FetchAttachment(std::string const& key, Json const& attach, int64_t chat, int64_t id, std::function<void(std::string)> apply) {
        if (key.empty()) return;
        attach_waiters_[key].push_back(std::move(apply));
        if (!photo_pending_.insert(key).second) return;
        auto self = get_strong();
        auto current = session_;
        auto dispatcher = Window::Current().Dispatcher();
        bool spawn = false;
        {
            std::lock_guard<std::mutex> lock(attach_mutex_);
            attach_jobs_.push_back({key, attach, chat, id, current});
            if (!attach_worker_) { attach_worker_ = true; spawn = true; }
        }
        if (!spawn) return;
        std::thread([self, current, dispatcher] {
            winrt::init_apartment(apartment_type::multi_threaded);
            for (;;) {
                AttachJob job;
                {
                    std::lock_guard<std::mutex> lock(self->attach_mutex_);
                    if (self->attach_jobs_.empty()) { self->attach_worker_ = false; return; }
                    job = self->attach_jobs_.front();
                    self->attach_jobs_.pop_front();
                }
                std::string url;
                try { if (!job.session) throw std::runtime_error("Нет соединения"); url = AttachmentUrl(job.session, job.attach, job.chat, job.id); HttpsUri(url); }
                catch (...) { url.clear(); }
                dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, job, url] {
                    self->photo_pending_.erase(job.key);
                    if (!url.empty()) self->photo_urls_[job.key] = url;
                    while (self->photo_urls_.size() > 800) self->photo_urls_.erase(self->photo_urls_.begin());
                    auto it = self->attach_waiters_.find(job.key);
                    if (it != self->attach_waiters_.end()) {
                        auto waiter = std::move(it->second);
                        self->attach_waiters_.erase(it);
                        for (auto const& apply : waiter) { try { apply(url); } catch (...) {} }
                    }
                });
            }
        }).detach();
    }

    std::string PhotoKey(Json const& attach, int64_t chat, int64_t id) {
        auto seed = FirstText(attach, {"baseUrl", "url"}) + "|" + FirstText(attach, {"photoToken", "token"});
        return std::to_string(chat) + ":" + std::to_string(id) + ":" + std::to_string(std::hash<std::string>{}(seed));
    }

    Grid ShowInlinePhoto(StackPanel const& body, Json const& attach, int64_t chat, int64_t id, int height, int width) {
        Grid frame;
        frame.Height(height);
        frame.HorizontalAlignment(HorizontalAlignment::Stretch);
        frame.Background(ResourceBrush(L"SystemControlBackgroundBaseLowBrush"));
        Image image;
        image.Stretch(Stretch::Uniform);
        frame.Children().Append(image);
        ProgressRing progress;
        progress.Width(32); progress.Height(32); progress.IsActive(true);
        progress.HorizontalAlignment(HorizontalAlignment::Center); progress.VerticalAlignment(VerticalAlignment::Center);
        frame.Children().Append(progress);
        auto error = Label(L"", 12);
        error.Margin(Thickness{8}); error.TextAlignment(TextAlignment::Center);
        error.VerticalAlignment(VerticalAlignment::Bottom);
        error.Visibility(Visibility::Collapsed);
        frame.Children().Append(error);
        body.Children().Append(frame);
        auto weak = get_weak();
        auto weak_image = make_weak(image);
        auto weak_progress = make_weak(progress);
        auto weak_error = make_weak(error);
        auto has_preview = std::make_shared<bool>(false);
        auto failed = std::make_shared<bool>(false);
        auto loading = std::make_shared<bool>(false);
        auto preview = AttachmentPreview(attach);
        if (!preview.empty()) {
            LoadImage("", preview, width, [weak_image, weak_progress, weak_error, has_preview, failed, loading](ImageSource const& source, hstring const&) {
                if (auto image = weak_image.get(); image && source && !*has_preview) {
                    image.Source(source); *has_preview = true;
                    if (auto ring = weak_progress.get()) { ring.IsActive(false); ring.Visibility(Visibility::Collapsed); }
                } else if (!source && !*loading && !*has_preview) {
                    *failed = true;
                    if (auto ring = weak_progress.get()) { ring.IsActive(false); ring.Visibility(Visibility::Collapsed); }
                    if (auto label = weak_error.get()) { label.Text(L"Не удалось показать превью. Нажмите для повтора."); label.Visibility(Visibility::Visible); }
                }
            });
        }
        auto load = [weak, weak_image, weak_progress, weak_error, attach, chat, id, width, failed, loading, has_preview] {
            auto self = weak.get();
            if (!self || *loading) return;
            *loading = true;
            *failed = false;
            if (auto error = weak_error.get()) error.Visibility(Visibility::Collapsed);
            if (auto ring = weak_progress.get()) { ring.IsActive(!*has_preview); ring.Visibility(*has_preview ? Visibility::Collapsed : Visibility::Visible); }
            auto key = self->PhotoKey(attach, chat, id);
            auto complete = [weak, weak_image, weak_progress, weak_error, failed, loading, has_preview, key](ImageSource const& source, hstring const& message) {
                *loading = false;
                *failed = !message.empty();
                if (auto ring = weak_progress.get()) { ring.IsActive(false); ring.Visibility(Visibility::Collapsed); }
                if (source) { if (auto image = weak_image.get()) image.Source(source); *has_preview = true; }
                if (!message.empty()) {
                    if (auto error = weak_error.get()) { error.Text(L"Не удалось загрузить фото. Нажмите на превью для повтора."); error.Visibility(Visibility::Visible); }
                    if (auto self = weak.get()) { self->photo_urls_.erase(key); self->LogConn(L"Фото: " + message); }
                }
            };
            auto show = [width, complete](std::string const& url) {
                if (url.empty()) { complete(nullptr, L"Ссылка изображения недоступна"); return; }
                LoadImage(url, {}, width, complete);
            };
            auto direct = Text(attach, "thumbnail");
            if (direct.empty()) direct = FirstText(attach, {"baseUrl", "url"});
            if (direct.empty() && !AttachmentPreview(attach).empty()) { *loading = false; return; }
            auto cached = self->photo_urls_.find(key);
            if (cached != self->photo_urls_.end()) show(cached->second);
            else self->FetchAttachment(key, attach, chat, id, show);
        };
        frame.Tapped([load, failed](auto const&, Input::TappedRoutedEventArgs const& args) { if (*failed) load(); args.Handled(true); });
        load();
        return frame;
    }

    void ShowInlineMedia(StackPanel const& body, Json const& attach, int64_t chat, int64_t id, bool video) {
        auto total = Integer(attach, "duration") / 1000;
        auto name = Text(attach, "name", video ? "Видео" : attach.contains("wave") ? "Голосовое сообщение" : "Аудио");
        StackPanel box;
        box.Margin(Thickness{0, 6, 0, 6});
        MediaElement player;
        player.AutoPlay(false);
        player.AreTransportControlsEnabled(video);
        player.Height(0);
        player.HorizontalAlignment(HorizontalAlignment::Stretch);
        Grid surface;
        surface.Height(200);
        surface.Background(ResourceBrush(L"SystemControlBackgroundBaseLowBrush"));
        StackPanel poster;
        if (video) {
            auto preview = Object(attach, "preview");
            if (preview.empty()) preview = Json::object();
            preview["_type"] = "PHOTO";
            if (!preview.contains("previewData") && attach.contains("previewData")) preview["previewData"] = attach.at("previewData");
            auto thumbnail = FirstText(attach, {"thumbnail", "baseUrl"});
            if (thumbnail.compare(0, 11, "data:image/") == 0) preview["previewData"] = thumbnail;
            else if (!thumbnail.empty()) preview["baseUrl"] = thumbnail;
            auto preview_url = Text(attach, "previewData");
            if (FirstText(preview, {"baseUrl", "url"}).empty() && preview_url.compare(0, 8, "https://") == 0) preview["baseUrl"] = preview_url;
            if (!FirstText(preview, {"baseUrl", "url"}).empty() || !AttachmentPreview(preview).empty()) ShowInlinePhoto(poster, preview, chat, id, 200, 480);
            else {
                SymbolIcon icon(Symbol::Video);
                icon.Width(48); icon.Height(48);
                icon.HorizontalAlignment(HorizontalAlignment::Center);
                icon.Margin(Thickness{0, 60, 0, 0});
                poster.Children().Append(icon);
            }
            surface.Children().Append(poster);
            surface.Children().Append(player);
            box.Children().Append(surface);
        } else box.Children().Append(player);
        Grid controls;
        ColumnDefinition left;
        left.Width(GridLengthHelper::Auto());
        controls.ColumnDefinitions().Append(left);
        controls.ColumnDefinitions().Append(ColumnDefinition());
        Button play;
        play.Content(SymbolIcon(Symbol::Play));
        play.Width(44);
        play.Height(44);
        play.Padding(Thickness{8});
        ToolTipService::SetToolTip(play, box_value(video ? L"Воспроизвести видео" : L"Воспроизвести аудио"));
        if (video) {
            play.Width(56); play.Height(56);
            play.HorizontalAlignment(HorizontalAlignment::Center); play.VerticalAlignment(VerticalAlignment::Center);
            play.Background(ResourceBrush(L"SystemControlBackgroundChromeMediumBrush"));
            surface.Children().Append(play);
        } else controls.Children().Append(play);
        auto caption = Label(to_hstring(name) + (total > 0 ? L" · " + to_hstring(total / 60) + L":" + (total % 60 < 10 ? L"0" : L"") + to_hstring(total % 60) : L""), 14);
        caption.Margin(Thickness{10, 0, 0, 0});
        caption.VerticalAlignment(VerticalAlignment::Center);
        Grid::SetColumn(caption, 1);
        controls.Children().Append(caption);
        box.Children().Append(controls);
        auto failed = Label(L"", 12);
        failed.Visibility(Visibility::Collapsed);
        box.Children().Append(failed);
        auto ready = std::make_shared<bool>(false);
        auto loading = std::make_shared<bool>(false);
        auto visible = std::make_shared<bool>(true);
        auto playback_file = std::make_shared<Windows::Storage::StorageFile>(nullptr);
        auto weak_player = make_weak(player);
        auto weak_play = make_weak(play);
        auto weak_error = make_weak(failed);
        auto weak_poster = make_weak(poster);
        player.Loaded([visible](auto const&, auto const&) { *visible = true; });
        player.Unloaded([weak_player, playback_file, ready, visible](auto const&, auto const&) {
            *visible = false;
            *ready = false;
            if (auto media = weak_player.get()) { media.Stop(); media.Source(nullptr); }
            if (*playback_file) { try { (*playback_file).DeleteAsync(); } catch (...) {} *playback_file = nullptr; }
        });
        player.CurrentStateChanged([weak_play, weak_player](auto const&, auto const&) {
            if (auto button = weak_play.get()) if (auto media = weak_player.get()) button.Content(SymbolIcon(media.CurrentState() == MediaElementState::Playing ? Symbol::Pause : Symbol::Play));
        });
        player.MediaOpened([weak_player](auto const&, auto const&) { if (auto media = weak_player.get()) media.Play(); });
        player.MediaEnded([weak_play, weak_player, weak_poster, video](auto const&, auto const&) {
            if (!video) return;
            if (auto button = weak_play.get()) button.Visibility(Visibility::Visible);
            if (auto poster = weak_poster.get()) poster.Visibility(Visibility::Visible);
            if (auto media = weak_player.get()) { media.Height(0); media.Position(std::chrono::seconds(0)); }
        });
        player.MediaFailed([weak_play, weak_error, weak_player, weak_poster, ready, video](auto const&, auto const&) {
            *ready = false;
            if (video) {
                if (auto poster = weak_poster.get()) poster.Visibility(Visibility::Visible);
                if (auto media = weak_player.get()) media.Height(0);
            }
            if (auto button = weak_play.get()) { button.IsEnabled(true); button.Visibility(Visibility::Visible); button.Content(SymbolIcon(Symbol::Play)); }
            if (auto error = weak_error.get()) { error.Text(L"Не удалось воспроизвести файл. Нажмите Play для повтора."); error.Visibility(Visibility::Visible); }
        });
        play.Click([this, weak_player, weak_play, weak_error, weak_poster, ready, loading, playback_file, visible, attach, chat, id, video](auto const&, auto const&) {
            auto media = weak_player.get();
            if (!media || *loading) return;
            if (*ready) {
                if (video) {
                    media.Height(200);
                    if (auto poster = weak_poster.get()) poster.Visibility(Visibility::Collapsed);
                    if (auto button = weak_play.get()) button.Visibility(Visibility::Collapsed);
                }
                if (media.CurrentState() == MediaElementState::Playing) media.Pause(); else media.Play();
                return;
            }
            *loading = true;
            if (auto button = weak_play.get()) button.IsEnabled(false);
            if (auto error = weak_error.get()) { error.Text(L"Загрузка…"); error.Visibility(Visibility::Visible); }
            auto current = session_;
            auto dispatcher = Window::Current().Dispatcher();
            std::thread([current, dispatcher, weak_player, weak_play, weak_error, weak_poster, ready, loading, playback_file, visible, attach, chat, id, video] {
                init_apartment(apartment_type::multi_threaded);
                std::string url;
                Windows::Storage::StorageFile audio{nullptr};
                Windows::Storage::Streams::IRandomAccessStream stream{nullptr};
                hstring error;
                try {
                    if (!current) throw std::runtime_error("Соединение ещё восстанавливается. Повторите воспроизведение.");
                    url = AttachmentUrl(current, attach, chat, id);
                    if (!video) {
                        audio = DecodeVoice(url);
                        stream = audio.OpenAsync(Windows::Storage::FileAccessMode::Read).get();
                    }
                } catch (hresult_error const& e) { error = e.message(); }
                catch (std::exception const& e) { error = to_hstring(e.what()); }
                dispatcher.RunAsync(CoreDispatcherPriority::Normal, [weak_player, weak_play, weak_error, weak_poster, ready, loading, playback_file, visible, url, audio, stream, error, video] {
                    *loading = false;
                    if (auto button = weak_play.get()) button.IsEnabled(true);
                    auto media = weak_player.get();
                    if (!media || !*visible) { if (audio) { try { audio.DeleteAsync(); } catch (...) {} } return; }
                    try {
                        if (!error.empty()) throw hresult_error(E_FAIL, error);
                        *ready = true;
                        if (auto label = weak_error.get()) label.Visibility(Visibility::Collapsed);
                        if (video) {
                            media.Height(200);
                            if (auto poster = weak_poster.get()) poster.Visibility(Visibility::Collapsed);
                            if (auto button = weak_play.get()) button.Visibility(Visibility::Collapsed);
                            media.Source(HttpsUri(url));
                        }
                        else {
                            *playback_file = audio;
                            media.SetSource(stream, audio.ContentType());
                        }
                    } catch (hresult_error const& e) {
                        *ready = false;
                        if (auto label = weak_error.get()) { label.Text(e.message()); label.Visibility(Visibility::Visible); }
                    }
                });
            }).detach();
        });
        if (!video) box.Children().Append(ButtonWith(L"Открыть / сохранить", [this, attach, chat, id] { OpenAttachmentViewer(attach, chat, id); }));
        body.Children().Append(box);
    }

    void OpenAttachmentViewer(Json const& attach, int64_t chat, int64_t id) {
        Run([attach, chat, id](auto session) { return Json(AttachmentUrl(session, attach, chat, id)); },
            [this, attach](Json result) {
                auto url = result.get<std::string>();
                auto panel = ToolsPanel(L"Вложение");
                auto type = Text(attach, "_type");
                if (type == "PHOTO" || type == "STICKER") {
                    Image image;
                    ApplyImageSource(image, url, 1080);
                    image.Stretch(Stretch::Uniform);
                    panel.Children().Append(image);
                } else if (type == "VIDEO" || type == "AUDIO") {
                    MediaElement player;
                    player.AreTransportControlsEnabled(true);
                    player.AutoPlay(false);
                    player.Source(HttpsUri(url));
                    player.MaxHeight(400);
                    panel.Children().Append(player);
                }
                panel.Children().Append(ButtonWith(L"Сохранить файл", [this, url, attach] { SaveAttachment(url, Text(attach, "name", "attachment")); }));
            }, L"Получение вложения…");
    }

    void RenderAttachments(StackPanel const& body, Json const& message) {
        auto rows = Array(message, "attaches");
        if (!rows.is_array()) return;
        auto id = Integer(message, "id");
        auto chat = chat_;
        for (auto const& attach : rows) {
            auto type = Text(attach, "_type", "Вложение");
            auto name = Text(attach, "name", type);
            if (type == "PHOTO" || type == "STICKER") { ShowInlinePhoto(body, attach, chat, id, type == "STICKER" ? 160 : 240, type == "STICKER" ? 160 : 480); continue; }
            if (type == "AUDIO" || type == "VIDEO") { ShowInlineMedia(body, attach, chat, id, type == "VIDEO"); continue; }
            if (type == "CONTROL") { body.Children().Append(Label(L"Событие: " + to_hstring(Text(attach, "event")))); continue; }
            if (type == "POLL") { RenderPoll(body, message, attach); continue; }
            auto button = ButtonWith(L"Открыть: " + to_hstring(name), [this, attach, chat, id] { OpenAttachmentViewer(attach, chat, id); });
            body.Children().Append(button);
        }
    }

    void SendSelectedFile(Windows::Storage::StorageFile const& file, int64_t chat) {
        if (page_ != Page::Conversation || chat_ != chat) return;
        if (!RequireOnline([this, file, chat] { SendSelectedFile(file, chat); })) return;
        Run([chat, file](auto session) { return UploadFile(session, file, chat, -Now()); }, [this, chat](Json data) {
            if (!data.contains("message")) { Status(L"Нет подтверждения отправки файла."); return; }
            if (page_ != Page::Conversation || chat_ != chat) return;
            messages_.push_back(data.at("message"));
            StoreHistory();
            cache_dirty_ = true;
            RenderMessages(true);
            Status(L"Файл отправлен");
        }, L"Загрузка файла…");
    }

    void PickFile(bool audio = false) {
        if (!RequireOnline([this, audio] { PickFile(audio); })) return;
        Windows::Storage::Pickers::FileOpenPicker picker;
        if (audio) for (auto extension : {L".mp3", L".m4a", L".aac", L".wav", L".ogg", L".opus"}) picker.FileTypeFilter().Append(extension);
        else picker.FileTypeFilter().Append(L"*");
        auto self = get_strong();
        auto chat = chat_;
        auto dispatcher = Window::Current().Dispatcher();
        picker.PickSingleFileAsync().Completed([self, chat, dispatcher](auto const& operation, auto state) {
            if (state != Windows::Foundation::AsyncStatus::Completed) return;
            auto file = operation.GetResults();
            if (!file) return;
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, chat, file] { self->SendSelectedFile(file, chat); });
        });
    }

    void SendPhoto(Windows::Storage::StorageFile const& file, bool avatar) {
        if (!RequireOnline([this, file, avatar] { SendPhoto(file, avatar); })) return;
        auto chat = chat_;
        Run([file, avatar, chat](auto session) {
            auto token = UploadPhoto(session, file, avatar);
            if (avatar) return session->Request(16, {{"photoToken", token}, {"avatarType", "USER_AVATAR"}});
            Json request = {{"chatId", chat}, {"notify", true}, {"message", {{"cid", -Now()}, {"attaches", Json::array({{{"_type", "PHOTO"}, {"photoToken", token}}})}}}};
            for (int i = 0; i < 20; ++i) {
                try { return session->Request(64, request); }
                catch (std::exception const& error) {
                    if (std::string(error.what()).find("not.ready") == std::string::npos || i == 19) throw;
                    std::this_thread::sleep_for(std::chrono::seconds(1));
                }
            }
            throw std::runtime_error("Фотография не готова. Обновите историю.");
        }, [this, avatar](Json data) {
            if (avatar) { ApplyProfile(data); ShowProfile(); }
            else { ShowConversation(); LoadHistory(false); }
            Status(L"Фотография загружена");
        }, L"Загрузка фотографии…");
    }

    void PickPhoto(bool avatar) {
        if (!RequireOnline([this, avatar] { PickPhoto(avatar); })) return;
        Windows::Storage::Pickers::FileOpenPicker picker;
        for (auto extension : {L".jpg", L".jpeg", L".png"}) picker.FileTypeFilter().Append(extension);
        auto self = get_strong();
        auto dispatcher = Window::Current().Dispatcher();
        picker.PickSingleFileAsync().Completed([self, avatar, dispatcher](auto const& operation, auto state) {
            if (state != Windows::Foundation::AsyncStatus::Completed) return;
            auto file = operation.GetResults();
            if (file) dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, file, avatar] { self->SendPhoto(file, avatar); });
        });
    }

    void TakePhoto() {
        if (!RequireOnline([this] { TakePhoto(); })) return;
        Windows::Media::Capture::CameraCaptureUI camera;
        auto self = get_strong();
        auto dispatcher = Window::Current().Dispatcher();
        camera.CaptureFileAsync(Windows::Media::Capture::CameraCaptureUIMode::Photo).Completed([self, dispatcher](auto const& operation, auto state) {
            if (state != Windows::Foundation::AsyncStatus::Completed) return;
            auto file = operation.GetResults();
            if (file) dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, file] { self->SendPhoto(file, false); });
        });
    }

    void CreatePoll() {
        StackPanel panel;
        TextBox title;
        title.Header(box_value(L"Вопрос"));
        panel.Children().Append(title);
        TextBox answers;
        answers.Header(box_value(L"Варианты: каждый с новой строки"));
        answers.AcceptsReturn(true);
        answers.Height(140);
        panel.Children().Append(answers);
        CheckBox multiple;
        multiple.Content(box_value(L"Можно выбрать несколько вариантов"));
        panel.Children().Append(multiple);
        CheckBox anonymous;
        anonymous.Content(box_value(L"Анонимный опрос"));
        anonymous.IsChecked(true);
        panel.Children().Append(anonymous);
        auto chat = chat_;
        Dialog(L"Новый опрос", panel, [this, title, answers, multiple, anonymous, chat] {
            Json rows = Json::array();
            auto text = to_string(answers.Text());
            size_t from = 0;
            while (from < text.size()) {
                auto end = text.find_first_of("\r\n", from);
                auto answer = text.substr(from, end == std::string::npos ? end : end - from);
                if (!answer.empty()) rows.push_back({{"text", answer}});
                if (end == std::string::npos) break;
                from = end + 1;
            }
            if (title.Text().empty() || rows.size() < 2 || rows.size() > 10) { Status(L"Нужны вопрос и от 2 до 10 вариантов ответа."); return; }
            auto settings = (anonymous.IsChecked().Value() ? 4 : 0) | (multiple.IsChecked().Value() ? 1 : 0);
            Action(64, {{"chatId", chat}, {"notify", true}, {"message", {{"cid", -Now()}, {"attaches", Json::array({{
                {"_type", "POLL"}, {"title", to_string(title.Text())}, {"answers", rows}, {"settings", settings}}})}}}}, L"Опрос создан", true);
        }, L"Отправить");
    }

    void ScheduleMessage() {
        if (!composer_ || composer_.Text().empty()) { Status(L"Сначала введите текст сообщения."); return; }
        StackPanel panel;
        DatePicker date;
        date.Header(box_value(L"Дата"));
        TimePicker time;
        time.Header(box_value(L"Время"));
        panel.Children().Append(date);
        panel.Children().Append(time);
        auto chat = chat_;
        auto text = to_string(composer_.Text());
        Dialog(L"Отправить позже", panel, [this, chat, text, date, time] {
            Windows::Globalization::Calendar calendar;
            calendar.SetDateTime(date.Date());
            calendar.ChangeClock(Windows::Globalization::ClockIdentifiers::TwentyFourHour());
            auto minutes = std::chrono::duration_cast<std::chrono::minutes>(time.Time()).count();
            calendar.Hour(int(minutes / 60));
            calendar.Minute(int(minutes % 60));
            calendar.Second(0);
            calendar.Nanosecond(0);
            auto when = std::chrono::duration_cast<std::chrono::milliseconds>(calendar.GetDateTime().time_since_epoch()).count() - INT64_C(11644473600000);
            if (when < Now() + 10000) { Status(L"Выберите время в будущем."); return; }
            auto reply = reply_id_;
            Run([chat, text, when, reply](auto session) {
                Json message = {{"cid", -Now()}, {"text", text}, {"elements", Json::array()}, {"attaches", Json::array()}, {"delayedAttributes", {{"timeToFire", when}, {"notifySender", true}}}};
                if (reply) message["link"] = {{"type", "REPLY"}, {"chatId", chat}, {"messageId", reply}};
                return session->Request(64, {{"chatId", chat}, {"message", message}, {"notify", true}});
            }, [this](Json) { composer_.Text(L""); reply_id_ = 0; composer_.Header(nullptr); Status(L"Сообщение запланировано"); }, L"Сохранение отложенного сообщения…");
        }, L"Запланировать");
    }

    void ShowStickers() {
        Run([](auto session) {
            auto data = session->Request(27, {{"type", "STICKER"}, {"sync", 0}});
            Json ids = Json::array();
            auto sections = Array(data, "sections");
            if (sections.is_array()) for (auto const& section : sections) {
                auto sets = Array(section, "stickerSets");
                if (sets.is_array()) for (auto const& id : sets) if (id.is_number_integer() && ids.size() < 100) ids.push_back(id);
            }
            return ids.empty() ? Json::object() : session->Request(28, {{"type", "STICKER_SET"}, {"ids", ids}});
        }, [this](Json data) {
            auto panel = ToolsPanel(L"Стикеры");
            auto sets = Array(data, "stickerSets");
            if (!sets.is_array() || sets.empty()) { panel.Children().Append(Label(L"Стикерпаки не найдены.")); return; }
            for (auto const& set : sets) panel.Children().Append(ButtonWith(to_hstring(Text(set, "name", "Стикерпак")), [this, set] { ShowStickerSet(set); }));
        }, L"Загрузка стикерпаков…");
    }

    void ShowStickerSet(Json const& set) {
        auto ids = Array(set, "stickers");
        if (ids.size() > 100) ids.erase(ids.begin() + 100, ids.end());
        Run([ids](auto session) { return session->Request(28, {{"type", "STICKER"}, {"ids", ids}}); }, [this, set](Json data) {
            auto panel = ToolsPanel(to_hstring(Text(set, "name", "Стикеры")));
            auto stickers = Array(data, "stickers");
            if (!stickers.is_array()) return;
            auto chat = chat_;
            for (auto const& sticker : stickers) {
                Button button;
                auto url = Text(sticker, "url");
                if (!url.empty()) {
                    Image image;
                    Imaging::BitmapImage source(HttpsUri(url));
                    source.DecodePixelWidth(160);
                    image.Source(source);
                    image.Height(120);
                    button.Content(image);
                } else button.Content(box_value(L"Стикер"));
                button.MinHeight(64);
                button.Click([this, sticker, chat](auto const&, auto const&) {
                    Action(64, {{"chatId", chat}, {"notify", true}, {"message", {{"cid", -Now()}, {"attaches", Json::array({{{"_type", "STICKER"}, {"stickerId", Integer(sticker, "id")}}})}}}}, L"Стикер отправлен", true);
                });
                panel.Children().Append(button);
            }
        }, L"Загрузка стикеров…");
    }

    void SaveAttachment(std::string const& url, std::string const& filename) {
        Windows::Storage::Pickers::FileSavePicker picker;
        picker.SuggestedFileName(to_hstring(filename));
        picker.FileTypeChoices().Insert(L"Файл", single_threaded_vector<hstring>({L".bin"}));
        auto self = get_strong();
        auto dispatcher = Window::Current().Dispatcher();
        picker.PickSaveFileAsync().Completed([self, dispatcher, url](auto const& operation, auto state) {
            if (state != Windows::Foundation::AsyncStatus::Completed) return;
            auto file = operation.GetResults();
            if (!file) return;
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, file, url] {
                self->Run([file, url](auto) { DownloadTo(url, file); return Json(nullptr); }, [self](Json) { self->Status(L"Файл сохранён"); }, L"Сохранение файла…");
            });
        });
    }

    void SearchGlobal() {
        Form(L"Поиск MAX", {L"Имя, название чата или канала"}, [this](auto values) {
            Run([values](auto session) { return session->Request(60, {{"type", "ALL"}, {"count", 30}, {"query", values[0]}}); }, [this](Json data) {
                auto panel = ToolsPanel(L"Результаты поиска");
                auto rows = Array(data, "result");
                if (!rows.is_array() || rows.empty()) { panel.Children().Append(Label(L"Ничего не найдено.")); return; }
                for (auto const& row : rows) {
                    auto chat = Object(row, "chat");
                    auto contact = Object(row, "contact");
                    if (Integer(chat, "id")) panel.Children().Append(ButtonWith(to_hstring(ChatTitle(chat)), [this, chat] {
                        auto id = Integer(chat, "id");
                        if (std::none_of(chats_.begin(), chats_.end(), [id](Json const& c) { return Integer(c, "id") == id; })) chats_.push_back(chat);
                        chat_ = id; ShowConversation(); LoadHistory(false);
                    }));
                    else if (auto id = Integer(contact, "id")) { contacts_[std::to_string(id)] = contact; panel.Children().Append(ButtonWith(to_hstring(ContactName(id)), [this, id] { ContactDetails(id); })); }
                }
            }, L"Поиск…");
        });
    }

    void SearchMessages() {
        auto chat = chat_;
        Form(L"Поиск в переписке", {L"Текст"}, [this, chat](auto values) {
            Run([chat, values](auto session) { return session->Request(73, {{"chatId", chat}, {"query", values[0]}, {"count", 50}}); }, [this](Json data) {
                auto rows = data.value("messages", Array(data, "result"));
                if (!rows.is_array()) { Status(L"Сервер не вернул сообщения."); return; }
                messages_ = rows;
                RenderMessages(false);
                Status(L"Результаты поиска · " + to_hstring(rows.size()));
            }, L"Поиск сообщений…");
        });
    }

    void CreateGroup() {
        StackPanel panel;
        TextBox title;
        title.Header(box_value(L"Название"));
        title.MaxLength(200);
        panel.Children().Append(title);
        CheckBox channel;
        channel.Content(box_value(L"Создать канал"));
        panel.Children().Append(channel);
        ListView members;
        members.MaxHeight(280);
        members.SelectionMode(ListViewSelectionMode::Multiple);
        for (auto it = contacts_.begin(); it != contacts_.end(); ++it) {
            auto id = Integer(it.value(), "id");
            if (!id || id == me_) continue;
            auto row = Label(to_hstring(ContactName(id)), 18);
            row.Tag(box_value(id));
            members.Items().Append(row);
        }
        panel.Children().Append(members);
        Dialog(L"Новая группа или канал", panel, [this, title, channel, members] {
            Json ids = Json::array();
            for (auto const& selected : members.SelectedItems()) ids.push_back(unbox_value<int64_t>(selected.as<FrameworkElement>().Tag()));
            auto name = to_string(title.Text());
            auto type = channel.IsChecked().Value() ? "CHANNEL" : "CHAT";
            if (name.empty()) { Status(L"Введите название."); return; }
            Run([name, type, ids](auto session) { return session->Request(64, {{"notify", true}, {"message", {{"cid", -Now()}, {"attaches", Json::array({{
                {"_type", "CONTROL"}, {"event", "new"}, {"chatType", type}, {"title", name}, {"userIds", ids}}})}}}}); },
                [this](Json data) { auto chat = Object(data, "chat"); if (!Integer(chat, "id")) { Status(L"Сервер не вернул созданную группу."); return; } chats_.push_back(chat); chat_ = Integer(chat, "id"); ShowConversation(); LoadHistory(false); }, L"Создание группы…");
        }, L"Создать");
    }

    void JoinChat() {
        Form(L"Вступить в чат или канал", {L"Ссылка-приглашение"}, [this](auto values) {
            Run([values](auto session) { return session->Request(57, {{"link", values[0]}}); }, [this](Json data) {
                auto chat = Object(data, "chat");
                auto id = Integer(chat, "id");
                if (!id) { Status(L"Запрос выполнен. Обновите список чатов."); return; }
                chats_.push_back(chat); chat_ = id; ShowConversation(); LoadHistory(false);
            }, L"Вступление…");
        });
    }

    void ChatInfo() {
        auto chat = chat_;
        Run([chat](auto session) { return session->Request(48, {{"chatIds", Json::array({chat})}}); }, [this, chat](Json data) {
            auto rows = Array(data, "chats");
            auto info = rows.is_array() && !rows.empty() ? rows[0] : Object(data, "chat");
            auto panel = ToolsPanel(to_hstring(ChatTitle(info)));
            auto url = ChatAvatarUrl(info);
            if (!url.empty()) {
                Image avatar;
                avatar.Width(120);
                avatar.Height(120);
                avatar.Margin(Thickness{0, 8, 0, 12});
                ApplyImageSource(avatar, url, 240);
                panel.Children().Append(avatar);
            }
            panel.Children().Append(Label(to_hstring(Text(info, "description"))));
            panel.Children().Append(Label(L"ID: " + to_hstring(chat)));
            panel.Children().Append(ButtonWith(L"Участники", [this, chat] {
                Run([chat](auto session) { return session->Request(59, {{"type", "MEMBER"}, {"chatId", chat}, {"count", 100}, {"marker", 0}}); }, [this](Json result) {
                    ApplyContacts(result);
                    auto panel = ToolsPanel(L"Участники");
                    auto members = Array(result, "members");
                    if (members.is_array()) for (auto const& member : members) {
                        auto contact = Object(member, "contact");
                        auto id = Integer(contact, "id", Integer(member, "id", Integer(member, "userId")));
                        if (!id) continue;
                        if (!contact.empty()) contacts_[std::to_string(id)] = contact;
                        panel.Children().Append(ButtonWith(to_hstring(ContactName(id)), [this, id] { ContactDetails(id); }));
                    }
                }, L"Загрузка участников…");
            }));
            panel.Children().Append(ButtonWith(L"Открепить сообщение", [this, chat] { Action(55, {{"chatId", chat}, {"pinMessageId", 0}}, L"Сообщение откреплено"); }));
            panel.Children().Append(ButtonWith(L"Покинуть чат", [this, chat] {
                Dialog(L"Покинуть чат?", box_value(L"Для возвращения может понадобиться приглашение."), [this, chat] { Action(58, {{"chatId", chat}}, L"Вы покинули чат"); }, L"Покинуть");
            }));
        }, L"Загрузка сведений…");
    }

    void MarkRead() {
        if (anti_read_) { Status(L"Отметки прочтения отключены в настройках."); return; }
        if (messages_.empty()) return;
        auto const& last = messages_.back();
        Action(50, {{"type", "READ_MESSAGE"}, {"chatId", chat_}, {"messageId", Integer(last, "id")}, {"mark", Integer(last, "time")}}, L"Отмечено прочитанным");
    }

    void RenderPoll(StackPanel const& body, Json const& message, Json const& attach) {
        auto poll = attach.value("poll", attach);
        body.Children().Append(Label(to_hstring(Text(poll, "question", Text(poll, "title", "Опрос"))), 18));
        auto answers = Array(poll, "answers");
        auto chat = chat_;
        auto id = Integer(message, "id");
        auto pollId = Integer(poll, "pollId", Integer(attach, "pollId"));
        if (!answers.is_array()) return;
        std::vector<std::pair<int64_t, Primitives::ToggleButton>> choices;
        auto state = Object(poll, "state");
        auto results = Array(state, "result");
        for (auto const& answer : answers) {
            auto answerId = Integer(answer, "answerId", Integer(answer, "id"));
            auto label = to_hstring(Text(answer, "text", "Вариант"));
            for (auto const& result : results) if (Integer(result, "answerId") == answerId) label = label + L" · " + to_hstring(Integer(result, "voteCount"));
            Primitives::ToggleButton choice{nullptr};
            if (Integer(poll, "settings") & 1) {
                CheckBox box;
                box.Content(box_value(label));
                choice = box;
            } else {
                RadioButton radio;
                radio.GroupName(L"poll:" + to_hstring(id));
                radio.Content(box_value(label));
                choice = radio;
            }
            choices.emplace_back(answerId, choice);
            body.Children().Append(choice);
        }
        if (choices.empty()) return;
        body.Children().Append(ButtonWith(L"Проголосовать", [this, chat, id, pollId, choices] {
            Json ids = Json::array();
            for (auto const& entry : choices) if (entry.second.IsChecked() && entry.second.IsChecked().Value()) ids.push_back(entry.first);
            if (ids.empty()) { Status(L"Выберите вариант ответа."); return; }
            Action(304, {{"messageId", id}, {"chatId", chat}, {"pollId", pollId}, {"answersIds", ids}}, L"Голос отправлен", true);
        }));
    }

    Json CacheSnapshot() {
        Json drafts = Json::object();
        for (auto const& entry : drafts_) drafts[std::to_string(entry.first)] = to_string(entry.second);
        return {{"version", 1}, {"account", me_}, {"profile", profile_}, {"contacts", contacts_},
            {"chats", chats_}, {"history", history_cache_}, {"drafts", drafts}};
    }

    void StoreHistory() {
        auto key = std::to_string(chat_);
        history_cache_[key] = messages_;
        auto& saved = history_cache_[key];
        if (saved.size() > 200) saved.erase(saved.begin(), saved.end() - 200);
        while (history_cache_.size() > 10) {
            auto it = history_cache_.begin();
            if (it.key() == key) ++it;
            history_cache_.erase(it);
        }
        cache_dirty_ = true;
    }

    void SaveCache(Windows::ApplicationModel::SuspendingDeferral const& deferral = nullptr) {
        if (!me_ || (cache_saving_ && !deferral)) { if (deferral) deferral.Complete(); return; }
        cache_saving_ = true;
        cache_dirty_ = false;
        auto snapshot = CacheSnapshot();
        auto epoch = Cache::Epoch().load();
        auto self = get_strong();
        auto dispatcher = Window::Current().Dispatcher();
        std::thread([self, snapshot, dispatcher, epoch, deferral] {
            init_apartment(apartment_type::multi_threaded);
            bool success = true;
            try { Cache::Write(snapshot, epoch); } catch (...) { success = false; }
            if (deferral) deferral.Complete();
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, success] {
                self->cache_saving_ = false;
                if (!success) self->Status(L"Не удалось сохранить локальную историю.");
            });
        }).detach();
    }

    void LoadCacheThenConnect() {
        auto values = Windows::Storage::ApplicationData::Current().LocalSettings().Values();
        auto account = values.HasKey(L"activeAccount") ? unbox_value<int64_t>(values.Lookup(L"activeAccount")) : 0;
        Run([](auto) { try { return Cache::Read(); } catch (...) { return Json(nullptr); } }, [this, account](Json data) {
            if (account && data.is_object() && Integer(data, "version") == 1 && Integer(data, "account") == account) {
                me_ = Integer(data, "account");
                profile_ = Object(data, "profile");
                contacts_ = Object(data, "contacts");
                chats_ = Array(data, "chats");
                history_cache_ = Object(data, "history");
                auto drafts = Object(data, "drafts");
                if (drafts.is_object()) for (auto it = drafts.begin(); it != drafts.end(); ++it) {
                    try { if (it.value().is_string()) drafts_[std::stoll(it.key())] = to_hstring(it.value().get<std::string>()); } catch (...) {}
                }
                ShowChats();
            }
            if (page_ == Page::Loading) ShowChats();
            Connect();
        }, L"Загрузка сохранённой истории…");
    }
