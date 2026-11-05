#include <windows.h>
#undef GetCurrentTime
#include "Session.h"
#include "../third_party/qrcodegen.hpp"
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.ApplicationModel.Activation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include "Cache.h"
#include "Media.h"
#include "Images.h"
#include "Background.h"
#include "ChatState.h"
#include <winrt/Windows.ApplicationModel.DataTransfer.h>
#include <winrt/Windows.Storage.Pickers.h>
#include <winrt/Windows.UI.Xaml.Media.Imaging.h>
#include <winrt/Windows.System.h>
#include <winrt/Windows.Media.Capture.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Security.Credentials.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.System.Profile.h>
#include <winrt/Windows.UI.Core.h>
#include <winrt/Windows.UI.ViewManagement.h>
#include <winrt/Windows.UI.Input.h>
#include <winrt/Windows.UI.Xaml.h>
#include <winrt/Windows.UI.Xaml.Controls.h>
#include <winrt/Windows.UI.Xaml.Controls.Primitives.h>
#include <winrt/Windows.UI.Xaml.Input.h>
#include <winrt/Windows.UI.Xaml.Interop.h>
#include <winrt/Windows.UI.Xaml.Markup.h>
#include <winrt/Windows.UI.Xaml.Media.h>
#include <winrt/Windows.UI.Xaml.Shapes.h>
#include <algorithm>
#include <ctime>
#include <cwctype>
#include <deque>
#include <functional>
#include <set>
#include <thread>

using namespace winrt;
using namespace Windows::UI::Xaml;
using namespace Windows::UI::Xaml::Controls;
using namespace Windows::UI::Xaml::Media;
using namespace Windows::UI::Core;

namespace komet {
using Windows::Security::Credentials::PasswordCredential;
using Windows::Security::Credentials::PasswordVault;

int64_t Now() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
}

TextBlock Label(hstring const& text, double size = 14) {
    TextBlock result;
    result.Text(text);
    result.FontSize(size);
    result.TextWrapping(TextWrapping::Wrap);
    return result;
}

Brush ResourceBrush(wchar_t const* name) {
    return Application::Current().Resources().Lookup(box_value(name)).as<Brush>();
}

Grid Avatar(std::string const& url, hstring const& name, double size = 48) {
    Grid avatar;
    avatar.Width(size);
    avatar.Height(size);
    avatar.VerticalAlignment(VerticalAlignment::Center);
    Shapes::Ellipse background;
    background.Fill(ResourceBrush(L"SystemControlBackgroundAccentBrush"));
    avatar.Children().Append(background);
    auto initial = Label(name.empty() ? L"?" : hstring(std::wstring(1, name.front())), size * 0.42);
    initial.HorizontalAlignment(HorizontalAlignment::Center);
    initial.VerticalAlignment(VerticalAlignment::Center);
    initial.Foreground(ResourceBrush(L"SystemControlForegroundAltHighBrush"));
    avatar.Children().Append(initial);
    if (!url.empty()) {
        try {
            Shapes::Ellipse picture;
            picture.Opacity(0);
            avatar.Children().Append(picture);
            auto weak_picture = make_weak(picture);
            LoadImage(url, {}, int(size * 2), [weak_picture](ImageSource const& source, hstring const& error) {
                if (auto shape = weak_picture.get(); shape && error.empty() && source) {
                    ImageBrush photo;
                    photo.Stretch(Stretch::UniformToFill);
                    photo.ImageSource(source);
                    shape.Fill(photo);
                    shape.Opacity(1);
                }
            });
        } catch (...) {}
    }
    return avatar;
}

template<typename T>
T VisualChild(DependencyObject const& parent) {
    if (auto match = parent.try_as<T>()) return match;
    for (int i = 0; i < VisualTreeHelper::GetChildrenCount(parent); ++i) {
        if (auto match = VisualChild<T>(VisualTreeHelper::GetChild(parent, i))) return match;
    }
    return nullptr;
}

struct App : ApplicationT<App, Markup::IXamlMetadataProvider> {
    std::shared_ptr<BackgroundService> background_ = std::make_shared<BackgroundService>();
    Grid root_;
    Grid content_;
    UserControl content_host_;
    TextBlock title_;
    TextBlock status_;
    ProgressBar progress_;
    CommandBar commands_;
    TextBox phone_{nullptr};
    TextBox code_{nullptr};
    Button retry_login_{nullptr};
    size_t code_length_ = 6;
    PasswordBox password_{nullptr};
    StackPanel otp_panel_;
    StackPanel password_panel_;
    StackPanel qr_panel_;
    TextBox composer_{nullptr};
    ListView chat_list_{nullptr};
    ListView message_list_{nullptr};
    TextBox search_{nullptr};
    DispatcherTimer timer_;
    DispatcherTimer qr_timer_;
    std::shared_ptr<Session> session_;
    Json chats_ = Json::array();
    Json messages_ = Json::array();
    std::map<int64_t, Json> rendered_messages_;
    std::map<int64_t, TextBlock> delivery_labels_;
    std::map<int64_t, int64_t> read_marks_;
    bool marking_read_ = false;
    Json contacts_ = Json::object();
    std::string token_;
    std::string otp_token_;
    std::string track_;
    std::string device_;
    std::string qr_track_;
    std::string auth_phone_;
    int64_t resend_after_ = 0;
    bool native_mode_ = true;
    int64_t qr_deadline_ = 0;
    int64_t me_ = 0;
    int64_t chat_ = 0;
    int64_t marker_ = 0;
    int generation_ = 0;
    int ticks_ = 0;
    bool busy_ = false;
    bool ui_ready_ = false;
    bool tools_return_conversation_ = false;
    bool online_ = false;
    bool dirty_ = false;
    bool suspended_ = false;
    bool pinging_ = false;
    bool presence_fetching_ = false;
    int64_t last_presence_fetch_ = 0;
    bool reconnecting_ = false;
    std::function<void()> online_action_;
    int64_t reconnect_after_ = 0;
    int64_t last_auto_refresh_ = 0;
    int fail_count_ = 0;
    std::map<std::string, std::string> photo_urls_;
    std::set<std::string> photo_pending_;
    std::set<std::string> names_fetching_;
    std::set<std::string> contact_details_fetched_;
    std::map<int64_t, hstring> drafts_;
    Json history_cache_ = Json::object();
    Json profile_ = Json::object();
    Json config_ = Json::object();
    Json presence_ = Json::object();
    TextBlock subtitle_{nullptr};
    Border header_avatar_{nullptr};
    std::vector<std::wstring> conn_log_;
    struct AttachJob {
        std::string key;
        Json attach;
        int64_t chat = 0;
        int64_t id = 0;
        std::shared_ptr<Session> session;
    };
    std::mutex attach_mutex_;
    std::deque<AttachJob> attach_jobs_;
    bool attach_worker_ = false;
    std::map<std::string, std::vector<std::function<void(std::string)>>> attach_waiters_;
    bool cache_dirty_ = false;
    bool cache_saving_ = false;
    int64_t reply_id_ = 0;
    bool anti_read_ = false;
    bool ghost_ = false;
    enum class Page { Loading, Login, Chats, Conversation, Tools, About };
    Page page_ = Page::Loading;

    Markup::IXamlType GetXamlType(Interop::TypeName const&) { return nullptr; }
    Markup::IXamlType GetXamlType(hstring const&) { return nullptr; }
    com_array<Markup::XmlnsDefinition> GetXmlnsDefinitions() { return {}; }

    void Status(hstring const& message) { status_.Text(message); }

    void LogConn(hstring const& line) {
        time_t seconds = time(nullptr);
        tm local{};
        localtime_s(&local, &seconds);
        wchar_t stamp[12]{};
        wcsftime(stamp, 12, L"%H:%M:%S", &local);
        auto wide = std::wstring(line.c_str());
        conn_log_.insert(conn_log_.begin(), std::wstring(stamp) + L" · " + wide);
        if (conn_log_.size() > 60) conn_log_.resize(60);
    }

    void SetBusy(bool value) {
        busy_ = value;
        content_host_.IsEnabled(!value || page_ == Page::Conversation);
        if (composer_) composer_.IsEnabled(!value);
        commands_.IsEnabled(!value);
        progress_.IsIndeterminate(value);
        progress_.Visibility(value ? Visibility::Visible : Visibility::Collapsed);
    }

    void Run(std::function<Json(std::shared_ptr<Session>)> work, std::function<void(Json)> done, hstring const& message) {
        if (busy_) return;
        SetBusy(true);
        Status(message);
        auto self = get_strong();
        auto dispatcher = Window::Current().Dispatcher();
        auto current = session_;
        auto generation = generation_;
        std::thread([self, dispatcher, current, generation, message, work = std::move(work), done = std::move(done)] {
            init_apartment(apartment_type::multi_threaded);
            Json result;
            hstring error;
            try { result = work(current); }
            catch (hresult_error const& e) { error = L"Ошибка Windows: " + e.message() + L" (" + to_hstring(int32_t(e.code())) + L")"; }
            catch (std::exception const& e) { error = to_hstring(e.what()); }
            catch (...) { error = L"Не удалось выполнить действие."; }
            if (!error.empty()) {
                std::wstring stage(message.c_str());
                while (!stage.empty() && (stage.back() == L'…' || stage.back() == L'.')) stage.pop_back();
                error = hstring(stage) + L": " + error;
            }
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, generation, result = std::move(result), error, done] {
                if (generation != self->generation_) return;
                if (self->suspended_) return;
                self->SetBusy(false);
                if (!error.empty()) {
                    if (self->page_ == Page::Loading) { if (self->token_.empty()) self->ShowLogin(); else self->ShowChats(); }
                    self->Status(error);
                    return;
                }
                try { self->Status(L"Готово"); done(result); }
                catch (hresult_error const& e) { self->Status(L"Ошибка: " + e.message()); }
                catch (std::exception const& e) { self->Status(to_hstring(e.what())); }
            });
        }).detach();
    }

    void Launch(std::function<Json(std::shared_ptr<Session>)> work, std::function<void(Json)> done, bool always = false) {
        auto self = get_strong();
        auto dispatcher = Window::Current().Dispatcher();
        auto current = session_;
        auto generation = generation_;
        std::thread([self, dispatcher, current, generation, always, work = std::move(work), done = std::move(done)] {
            init_apartment(apartment_type::multi_threaded);
            Json result;
            try { result = work(current); } catch (...) {}
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, generation, always, result = std::move(result), done] {
                if (!always && (generation != self->generation_ || self->suspended_)) return;
                try { done(result); } catch (...) {}
            });
        }).detach();
    }

    void NewSession(bool native = true) {
        marking_read_ = false;
        names_fetching_.clear();
        contact_details_fetched_.clear();
        presence_fetching_ = false;
        last_presence_fetch_ = 0;
        qr_timer_.Stop();
        qr_track_.clear();
        if (session_) session_->Close();
        online_ = false;
        native_mode_ = native;
        session_ = std::make_shared<Session>();
        auto weak = get_weak();
        auto expected = std::weak_ptr<Session>(session_);
        auto dispatcher = Window::Current().Dispatcher();
        session_->OnError([weak, expected, dispatcher](std::string const& reason) {
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [weak, expected, reason] {
                if (auto self = weak.get(); self && self->session_ == expected.lock()) self->LogConn(to_hstring(reason));
            });
        });
        session_->OnPush([weak, expected, dispatcher](Frame frame) {            if (frame.opcode == 132) {
                auto payload = frame.payload;
                dispatcher.RunAsync(CoreDispatcherPriority::Normal, [weak, expected, payload = std::move(payload)] {
                    if (auto self = weak.get(); self && self->session_ == expected.lock()) self->ApplyPresenceUpdate(payload);
                });
                return;
            }
            if (frame.opcode == 130) {
                auto payload = frame.payload;
                dispatcher.RunAsync(CoreDispatcherPriority::Normal, [weak, expected, payload] {
                    if (auto self = weak.get(); self && self->session_ == expected.lock()) self->ApplyReadMark(payload);
                });
                return;
            }
            if (frame.opcode != 128 && frame.opcode != 135 && frame.opcode != 142 && frame.opcode != 140) return;
            auto payload = frame.payload;
            auto opcode = frame.opcode;
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [weak, expected, opcode, payload = std::move(payload)] {
                if (auto self = weak.get(); self && self->session_ == expected.lock()) {
                    self->dirty_ = true;
                    if (opcode == 128) {
                        auto chat = Integer(payload, "chatId");
                        auto message = Object(payload, "message");
                        if (self->background_->foreground && self->page_ == Page::Conversation && self->chat_ == chat) {
                            auto time = Integer(message, "time");
                            if (time > 0) Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"notified:" + to_hstring(self->me_) + L":" + to_hstring(chat), box_value(time));
                        } else {
                            try { NotifyMessage(message, chat, self->me_, Json{{"chats", self->chats_}, {"contacts", self->contacts_}}); } catch (...) {}
                        }
                    }
                }
            });
        });
        session_->OnDisconnected([weak, expected, dispatcher] {
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [weak, expected] {
                if (auto self = weak.get(); self && self->session_ == expected.lock() && !self->suspended_) {
                    self->online_ = false;
                    self->otp_token_.clear();
                    self->track_.clear();
                    self->qr_track_.clear();
                    self->qr_timer_.Stop();
                    self->reconnect_after_ = self->reconnecting_ ? std::max(self->reconnect_after_, Now() + self->ReconnectDelay()) : Now() + 2000;
                    self->Status(L"Нет соединения");
                    self->LogConn(L"соединение потеряно");
                }
            });
        });
    }

    void SaveToken() {
        PasswordVault vault;
        try { vault.Remove(vault.Retrieve(L"KometW10M", L"session")); }
        catch (hresult_error const& e) { if (e.code() != HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) throw; }
        vault.Add(PasswordCredential(L"KometW10M", L"session", to_hstring(token_)));
        auto alias = L"account:" + to_hstring(me_);
        try { vault.Remove(vault.Retrieve(L"KometW10M", alias)); }
        catch (hresult_error const& e) { if (e.code() != HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) throw; }
        vault.Add(PasswordCredential(L"KometW10M", alias, to_hstring(token_)));
        Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"nativeTransport", box_value(native_mode_));
        Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"activeAccount", box_value(me_));
        Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"transport:" + to_hstring(me_), box_value(native_mode_));
    }

    void LoadIdentity() {
        auto values = Windows::Storage::ApplicationData::Current().LocalSettings().Values();
        if (values.HasKey(L"ghost")) ghost_ = unbox_value<bool>(values.Lookup(L"ghost"));
        if (values.HasKey(L"antiRead")) anti_read_ = unbox_value<bool>(values.Lookup(L"antiRead"));
        if (values.HasKey(L"deviceId")) device_ = to_string(unbox_value<hstring>(values.Lookup(L"deviceId")));
        else {
            GUID id;
            check_hresult(CoCreateGuid(&id));
            device_ = to_string(to_hstring(id));
            if (device_.front() == '{') device_ = device_.substr(1, device_.size() - 2);
            values.Insert(L"deviceId", box_value(to_hstring(device_)));
        }
        try {
            auto credential = PasswordVault().Retrieve(L"KometW10M", L"session");
            credential.RetrievePassword();
            token_ = to_string(credential.Password());
            native_mode_ = values.HasKey(L"nativeTransport") && unbox_value<bool>(values.Lookup(L"nativeTransport"));
        } catch (hresult_error const& e) {
            if (e.code() != HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) throw;
        }
    }

    Json Login(std::shared_ptr<Session> const& session, std::string const& token) {
        return session->Login(token, !ghost_);
    }

    void ApplyContacts(Json const& data) {
        auto raw = Array(data, "contacts");
        if (raw.is_array()) for (auto const& item : raw) {
            if (item.is_object()) contacts_[std::to_string(Integer(item, "id"))] = item;
        }
    }

    void FetchContactNames(Json const& ids, std::function<void()> done) {
        auto self = get_strong();
        auto generation = generation_;
        Launch([ids](auto session) { return session->Request(32, {{"contactIds", ids}}); },
            [self, generation, ids, done = std::move(done)](Json data) {
                if (generation != self->generation_ || self->suspended_) return;
                bool merged = data.is_object() && data.contains("contacts") && data.at("contacts").is_array();
                if (merged) {
                    self->ApplyContacts(data);
                    self->cache_dirty_ = true;
                }
                for (auto const& id : ids) {
                    if (!id.is_number_integer()) continue;
                    auto key = std::to_string(id.get<int64_t>());
                    self->names_fetching_.erase(key);
                    if (merged) self->contact_details_fetched_.insert(key);
                    if (merged && !self->contacts_.count(key)) self->contacts_[key] = {{"id", id}};
                }
                done();
                if (merged) self->ResolveNames();
            }, true);
    }

    void ResolveNames() {
        Json ids = Json::array();
        auto missing = [&](int64_t id) {
            if (!id || id == me_) return;
            auto key = std::to_string(id);
            if (names_fetching_.count(key) || contact_details_fetched_.count(key) || ids.size() >= 100) return;
            auto contact = contacts_.find(key);
            if (contact != contacts_.end() && !FirstText(*contact, {"baseUrl", "iconUrl"}).empty()) return;
            names_fetching_.insert(key);
            ids.push_back(id);
        };
        for (auto const& chat : chats_) if (Text(chat, "type") == "DIALOG" && Integer(chat, "id") != 0) missing(Integer(chat, "id") ^ me_);
        for (auto const& chat : chats_) {
            auto participants = Object(chat, "participants");
            if (participants.is_object()) for (auto it = participants.begin(); it != participants.end(); ++it) {
                try { missing(std::stoll(it.key())); } catch (...) {}
            }
            if (Text(chat, "type") == "DIALOG") {
                auto id = Integer(chat, "id");
                if (id != 0) missing(id ^ me_);
            }
        }
        if (page_ == Page::Conversation) for (auto const& message : messages_) missing(Integer(message, "sender"));
        if (ids.empty()) return;
        FetchContactNames(ids, [this] {
            if (page_ == Page::Chats) RenderChats();
            if (page_ == Page::Conversation) {
                for (auto const& item : chats_) if (Integer(item, "id") == chat_) title_.Text(to_hstring(ChatTitle(item)));
                ShowConversationHeader();
                if (message_list_) RenderMessages(false);
            }
        });
    }

    void ApplyLogin(Json const& data, bool quiet = false) {
        if (!data.is_object()) throw std::runtime_error("Некорректный ответ входа");
        auto profile = Object(data, "profile");
        if (profile.empty()) profile = profile_;
        profile_ = profile;
        config_ = Object(data, "config");
        auto previous = me_;
        me_ = AccountId(data);
        if (me_ <= 0) me_ = AccountId(Json{{"profile", profile}});
        if (me_ <= 0) me_ = previous;
        if (me_ <= 0) throw std::runtime_error("Сервер не вернул профиль аккаунта. Вход не завершён.");
        if (previous && previous != me_) {
            history_cache_ = Json::object();
            contacts_ = Json::object();
            drafts_.clear();
            chat_ = 0;
            Cache::Invalidate();
        }
        auto updated = Text(data, "token");
        if (!updated.empty()) token_ = updated;
        SaveToken();
        online_ = true;
        otp_token_.clear();
        track_.clear();
        ApplyContacts(data);
        ApplyPresence(data);
        if (profile.is_object()) {
            auto contact = Object(profile, "contact");
            if (Integer(contact, "id")) contacts_[std::to_string(me_)] = contact;
        }
        Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"name:" + to_hstring(me_), box_value(to_hstring(ContactName(me_))));
        chats_ = Array(data, "chats");
        if (!chats_.is_array()) chats_ = Json::array();
        marker_ = Integer(data, "chatMarker");
        auto settings = Windows::Storage::ApplicationData::Current().LocalSettings().Values();
        for (auto const& item : chats_) {
            auto stamp = Integer(Object(item, "lastMessage"), "time");
            if (stamp > 0) settings.Insert(L"notified:" + to_hstring(me_) + L":" + to_hstring(Integer(item, "id")), box_value(stamp));
        }
        ResolveNames();
        FetchPresence();
        cache_dirty_ = true;
        Status(L"Подключено");
        if (quiet) {
            if (page_ == Page::Conversation) { ShowConversationHeader(); dirty_ = true; }
            else if (page_ == Page::Chats && chat_list_) RenderChats();
            else if (page_ != Page::Tools && page_ != Page::About) { chat_ = 0; ShowChats(); }
            return;
        }
        if (page_ == Page::Conversation) {
            ShowConversation();
            LoadHistory(false);
        } else {
            chat_ = 0;
            ShowChats();
            Status(L"Подключено · " + to_hstring(chats_.size()) + L" чатов");
        }
    }

    bool RequireOnline(std::function<void()> action) {
        if (busy_) { Status(L"Дождитесь завершения текущего действия."); return false; }
        if (online_) return true;
        if (token_.empty()) { Status(L"Сначала войдите в аккаунт."); return false; }
        auto expected = chat_;
        auto account = me_;
        auto generation = generation_;
        auto page = page_;
        online_action_ = [this, expected, account, generation, page, action] { if (generation_ == generation && me_ == account && page_ == page && chat_ == expected) action(); };
        Status(L"Восстанавливаю соединение…");
        reconnect_after_ = 0;
        Reconnect();
        return false;
    }

    void ResumeOnlineAction() {
        auto action = std::move(online_action_);
        online_action_ = nullptr;
        if (action) action();
    }

    void Connect() {
        if (busy_ || reconnecting_) return;
        NewSession(native_mode_);
        auto device = device_;
        auto token = token_;
        auto native = native_mode_;
        auto self = get_strong();
        Run([self, device, token, native](auto session) {
            session->Connect(device, native);
            return token.empty() ? Json(nullptr) : self->Login(session, token);
        }, [this](Json data) {
            if (!data.is_null()) { ApplyLogin(data, bool(online_action_)); ResumeOnlineAction(); }
            else Status(L"Соединение установлено. Введите номер телефона.");
        }, L"Подключение…");
    }

    int64_t ReconnectDelay() {
        return std::min<int64_t>(30000 << std::min(fail_count_, 2), 150000);
    }

    void Reconnect() {
        if (reconnecting_ || busy_ || token_.empty() || suspended_) return;
        reconnecting_ = true;
        LogConn(L"переподключение к MAX");
        NewSession(native_mode_);
        auto device = device_;
        auto token = token_;
        auto native = native_mode_;
        auto self = get_strong();
        auto current = session_;
        auto generation = generation_;
        auto dispatcher = Window::Current().Dispatcher();
        std::thread([self, current, generation, dispatcher, device, token, native] {
            init_apartment(apartment_type::multi_threaded);
            bool ok = false;
            Json data;
            hstring error;
            try {
                current->Connect(device, native);
                data = self->Login(current, token);
                ok = true;
            } catch (hresult_error const& e) { error = e.message(); }
            catch (std::exception const& e) { error = to_hstring(e.what()); }
            catch (...) { error = L"Сервер недоступен."; }
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, current, generation, ok, data = std::move(data), error = std::move(error)] {
                if (generation != self->generation_ || self->suspended_ || self->session_ != current) {
                    return;
                }
                self->reconnecting_ = false;
                if (!ok) {
                    self->Status(L"Нет соединения. " + error);
                    self->LogConn(L"не удалось переподключиться: " + hstring(error.c_str()));
                    ++self->fail_count_;
                    self->reconnect_after_ = Now() + self->ReconnectDelay();
                    return;
                }
                self->fail_count_ = 0;
                self->reconnect_after_ = 0;
                try {
                    self->ApplyLogin(data, true);
                    self->LogConn(L"соединение восстановлено");
                } catch (...) {
                    self->online_ = false;
                    self->reconnect_after_ = Now() + self->ReconnectDelay();
                    self->Status(L"Не удалось восстановить сеанс.");
                    self->LogConn(L"восстановление сеанса не принято");
                    return;
                }
                try { self->ResumeOnlineAction(); }
                catch (hresult_error const& e) { self->Status(e.message()); }
                catch (std::exception const& e) { self->Status(to_hstring(e.what())); }
            });
        }).detach();
    }

    Button ButtonWith(hstring const& text, std::function<void()> action) {
        Button button;
        button.Content(box_value(text));
        button.MinHeight(44);
        button.HorizontalAlignment(HorizontalAlignment::Stretch);
        button.Margin(Thickness{0, 8, 0, 0});
        button.Click([action](auto const&, auto const&) { action(); });
        return button;
    }

    void AddCommand(Symbol symbol, hstring const& label, std::function<void()> action, bool secondary = false) {
        AppBarButton button;
        button.Icon(SymbolIcon(symbol));
        button.Label(label);
        button.Click([action](auto const&, auto const&) { action(); });
        if (secondary) commands_.SecondaryCommands().Append(button);
        else commands_.PrimaryCommands().Append(button);
    }

    void PageStart(Page page, hstring const& title, bool refresh_primary = true) {
        if ((page == Page::Tools || page == Page::About) && page_ == Page::Conversation) tools_return_conversation_ = true;
        if (page == Page::Chats || page == Page::Login || page == Page::Conversation) tools_return_conversation_ = false;
        page_ = page;
        composer_ = nullptr;
        message_list_ = nullptr;
        rendered_messages_.clear();
        delivery_labels_.clear();
        chat_list_ = nullptr;
        title_.Text(title);
        ResetHeaderAvatar();
        content_.Children().Clear();
        commands_.PrimaryCommands().Clear();
        commands_.SecondaryCommands().Clear();
        auto back = page == Page::Conversation || page == Page::About || page == Page::Tools;
        SystemNavigationManager::GetForCurrentView().AppViewBackButtonVisibility(
            back ? AppViewBackButtonVisibility::Visible : AppViewBackButtonVisibility::Collapsed);
        if (back) AddCommand(Symbol::Back, L"Назад", [this] { Back(); });
        if (refresh_primary) AddCommand(Symbol::Refresh, L"Обновить", [this] { Refresh(); });
        AddCommand(Symbol::Sync, L"Подключиться", [this] { Connect(); }, true);
        AddCommand(Symbol::Help, L"О приложении", [this] { ShowAbout(); }, true);
        AddCommand(Symbol::People, L"Контакты", [this] { ShowContacts(); }, true);
        AddCommand(Symbol::Contact, L"Мой профиль", [this] { ShowProfile(); }, true);
        AddCommand(Symbol::Setting, L"Настройки", [this] { ShowSettings(); }, true);
        AddCommand(Symbol::Switch, L"Аккаунты", [this] { ShowAccounts(); }, true);
        AddCommand(Symbol::Phone, L"История звонков", [this] { ShowCallHistory(); }, true);
        AddCommand(Symbol::Cancel, L"Выйти", [this] { Logout(); }, true);
    }

    void ShowLoading() {
        page_ = Page::Loading;
        title_.Text(L"Komet");
        ResetHeaderAvatar();
        content_.Children().Clear();
        commands_.PrimaryCommands().Clear();
        commands_.SecondaryCommands().Clear();
        StackPanel panel;
        panel.HorizontalAlignment(HorizontalAlignment::Center);
        panel.VerticalAlignment(VerticalAlignment::Center);
        auto name = Label(L"Komet", 36);
        name.HorizontalAlignment(HorizontalAlignment::Center);
        panel.Children().Append(name);
        ProgressRing ring;
        ring.IsActive(true); ring.Width(44); ring.Height(44); ring.Margin(Thickness{0, 24, 0, 16});
        panel.Children().Append(ring);
        panel.Children().Append(Label(L"Загрузка аккаунта и чатов…", 16));
        content_.Children().Append(panel);
        Status(L"Загрузка…");
    }

    void ShowLogin() {
        PageStart(Page::Login, L"Komet");
        StackPanel panel;
        panel.Margin(Thickness{20, 12, 20, 24});
        panel.MaxWidth(440);
        panel.Children().Append(Label(L"Вход в MAX", 24));
        auto intro = Label(L"Нативный клиент для Windows 10 Mobile. Используйте существующий аккаунт MAX.");
        intro.Margin(Thickness{0, 12, 0, 20});
        panel.Children().Append(intro);
        phone_ = TextBox();
        phone_.Header(box_value(L"Номер телефона"));
        phone_.PlaceholderText(L"+7 900 000-00-00");
        Input::InputScope scope;
        Input::InputScopeName name;
        name.NameValue(Input::InputScopeNameValue::TelephoneNumber);
        scope.Names().Append(name);
        phone_.InputScope(scope);
        panel.Children().Append(phone_);
        panel.Children().Append(ButtonWith(L"Получить код", [this] { RequestCode(); }));
        panel.Children().Append(ButtonWith(L"Войти по QR-коду", [this] { StartQr(); }));
        retry_login_ = ButtonWith(L"Повторить загрузку аккаунта", [this] { Connect(); });
        retry_login_.Visibility(token_.empty() ? Visibility::Collapsed : Visibility::Visible);
        panel.Children().Append(retry_login_);
        qr_panel_ = StackPanel();
        qr_panel_.Visibility(Visibility::Collapsed);
        panel.Children().Append(qr_panel_);
        code_ = TextBox();
        code_.Header(box_value(L"Код подтверждения"));
        code_.Margin(Thickness{0, 20, 0, 0});
        code_.MaxLength(12);
        Input::InputScope codeScope;
        Input::InputScopeName codeName;
        codeName.NameValue(Input::InputScopeNameValue::Number);
        codeScope.Names().Append(codeName);
        code_.InputScope(codeScope);
        otp_panel_ = StackPanel();
        otp_panel_.Visibility(Visibility::Collapsed);
        otp_panel_.Children().Append(code_);
        otp_panel_.Children().Append(ButtonWith(L"Войти по коду", [this] { VerifyCode(); }));
        otp_panel_.Children().Append(ButtonWith(L"Запросить код повторно", [this] { ResendCode(); }));
        panel.Children().Append(otp_panel_);
        password_ = PasswordBox();
        password_.Header(box_value(L"Пароль двухэтапной проверки"));
        password_.Margin(Thickness{0, 20, 0, 0});
        password_panel_ = StackPanel();
        password_panel_.Visibility(Visibility::Collapsed);
        password_panel_.Children().Append(password_);
        password_panel_.Children().Append(ButtonWith(L"Подтвердить пароль", [this] { VerifyPassword(); }));
        panel.Children().Append(password_panel_);
        auto note = Label(L"Код может прийти в MAX или по SMS — способ выбирает сервер. Эта версия поддерживает текстовые сообщения; звонки и вложения ещё не перенесены.");
        note.Margin(Thickness{0, 24, 0, 0});
        panel.Children().Append(note);
        ScrollViewer scroll;
        scroll.Content(panel);
        content_.Children().Append(scroll);
    }

    void RequestCode() {
        std::string phone;
        try { phone = NormalizePhone(to_string(phone_.Text())); }
        catch (std::exception const& error) { Status(to_hstring(error.what())); return; }
        NewSession(true);
        auth_phone_ = phone;
        otp_token_.clear();
        track_.clear();
        password_panel_.Visibility(Visibility::Collapsed);
        qr_panel_.Visibility(Visibility::Collapsed);
        auto device = device_;
        Run([device, phone](auto session) {
            session->Connect(device, true);
            return session->RequestCode(phone, false);
        }, [this](Json data) {
            otp_token_ = Text(data, "token");
            if (otp_token_.empty()) throw std::runtime_error("Сервер не вернул токен подтверждения");
            otp_panel_.Visibility(Visibility::Visible);
            code_length_ = size_t(std::clamp(Integer(data, "codeLength", 6), INT64_C(4), INT64_C(8)));
            resend_after_ = Now() + std::max(INT64_C(30000), Integer(data, "resendTimeout", 30000));
            Status(to_hstring(DeliveryStatus(data)));
            code_.Focus(FocusState::Programmatic);
        }, L"Запрос кода…");
    }

    void ResendCode() {
        if (!session_ || auth_phone_.empty() || otp_token_.empty()) { Status(L"Сначала запросите код."); return; }
        if (Now() < resend_after_) { Status(L"Повторный запрос будет доступен через " + to_hstring((resend_after_ - Now() + 999) / 1000) + L" сек."); return; }
        auto phone = auth_phone_;
        Run([phone](auto session) { return session->RequestCode(phone, true); }, [this](Json data) {
            auto token = Text(data, "token");
            if (!token.empty()) otp_token_ = token;
            resend_after_ = Now() + std::max(INT64_C(30000), Integer(data, "resendTimeout", 30000));
            Status(to_hstring(DeliveryStatus(data)));
        }, L"Повторный запрос кода…");
    }

    void AuthResult(Json const& data) {
        qr_timer_.Stop();
        qr_track_.clear();
        qr_panel_.Visibility(Visibility::Collapsed);
        auto attrs = Object(data, "tokenAttrs");
        token_ = Text(Object(attrs, "LOGIN"), "token");
        if (token_.empty()) {
            track_ = Text(Object(data, "passwordChallenge"), "trackId");
            if (!track_.empty()) {
                password_panel_.Visibility(Visibility::Visible);
                Status(L"Введите пароль двухэтапной проверки.");
                password_.Focus(FocusState::Programmatic);
                return;
            }
            auto registration = Text(Object(attrs, "REGISTER"), "token");
            if (!registration.empty()) { RegisterAccount(registration); return; }
            throw std::runtime_error("Вход не завершён. Регистрация новых аккаунтов пока не поддерживается.");
        }
        auto self = get_strong();
        auto profile = Object(data, "profile");
        if (!profile.empty()) profile_ = profile;
        auto account = AccountId(data);
        if (account > 0) { me_ = account; SaveToken(); }
        retry_login_.Visibility(Visibility::Visible);
        auto token = token_;
        Run([self, token](auto session) { return self->Login(session, token); },
            [this](Json login) { ApplyLogin(login); }, L"Загрузка чатов…");
    }

    void VerifyCode() {
        std::string code;
        try { code = NormalizeCode(to_string(code_.Text()), code_length_); }
        catch (std::exception const& error) { Status(to_hstring(error.what())); return; }
        if (otp_token_.empty() || code.empty() || !session_) { Status(L"Сначала запросите код."); return; }
        auto token = otp_token_;
        code_.Text(L"");
        Run([code, token](auto session) {
            return session->Request(18, {{"token", token}, {"verifyCode", code}, {"authTokenType", "CHECK_CODE"}});
        }, [this](Json data) { AuthResult(data); }, L"Проверка кода…");
    }

    void StartQr() {
        NewSession(false);
        otp_token_.clear();
        track_.clear();
        otp_panel_.Visibility(Visibility::Collapsed);
        password_panel_.Visibility(Visibility::Collapsed);
        qr_panel_.Visibility(Visibility::Collapsed);
        auto device = device_;
        Run([device](auto session) {
            session->Connect(device);
            return session->Request(288);
        }, [this](Json data) {
            qr_track_ = Text(data, "trackId");
            auto link = Text(data, "qrLink");
            if (qr_track_.empty() || link.empty()) throw std::runtime_error("Сервер не вернул QR-код входа");
            auto qr = qrcodegen::QrCode::encodeText(link.c_str(), qrcodegen::QrCode::Ecc::LOW);
            auto size = qr.getSize() + 8;
            std::wstring path;
            for (int y = 0; y < qr.getSize(); ++y) for (int x = 0; x < qr.getSize(); ++x) {
                if (qr.getModule(x, y)) path += L"M" + std::to_wstring(x + 4) + L"," + std::to_wstring(y + 4) + L"h1v1h-1z ";
            }
            auto xaml = L"<Viewbox xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\" Height=\"256\" Margin=\"0,16,0,16\"><Canvas Width=\"" +
                std::to_wstring(size) + L"\" Height=\"" + std::to_wstring(size) +
                L"\" Background=\"White\"><Path Fill=\"Black\" Data=\"" + path + L"\"/></Canvas></Viewbox>";
            qr_panel_.Children().Clear();
            qr_panel_.Children().Append(Markup::XamlReader::Load(xaml).as<UIElement>());
            qr_panel_.Children().Append(Label(L"Отсканируйте код в MAX на другом телефоне и подтвердите вход. Код действует ограниченное время."));
            qr_panel_.Visibility(Visibility::Visible);
            qr_deadline_ = Now() + std::clamp(Integer(data, "ttl", 120000), INT64_C(1000), INT64_C(600000));
            qr_timer_.Interval(std::chrono::milliseconds(std::clamp(Integer(data, "pollingInterval", 5000), INT64_C(2000), INT64_C(30000))));
            qr_timer_.Start();
            Status(L"Ожидание подтверждения в MAX…");
        }, L"Создание QR-кода…");
    }

    void PollQr() {
        if (busy_ || page_ != Page::Login || qr_track_.empty()) return;
        if (Now() >= qr_deadline_) {
            qr_timer_.Stop();
            qr_track_.clear();
            qr_panel_.Visibility(Visibility::Collapsed);
            Status(L"QR-код истёк. Нажмите «Войти по QR-коду» ещё раз.");
            return;
        }
        auto track = qr_track_;
        Run([track](auto session) {
            auto state = session->Request(289, {{"trackId", track}});
            auto status = Object(state, "status");
            if (status.value("loginAvailable", false)) return session->Request(291, {{"trackId", track}});
            return Json(nullptr);
        }, [this](Json result) {
            if (!result.is_null()) AuthResult(result);
            else Status(L"Ожидание подтверждения в MAX…");
        }, L"Ожидание подтверждения в MAX…");
    }

    void VerifyPassword() {
        auto password = to_string(password_.Password());
        if (track_.empty() || password.empty()) { Status(L"Пароль нужен только после запроса сервера."); return; }
        auto track = track_;
        password_.Password(L"");
        Run([track, password](auto session) {
            return session->Request(115, {{"trackId", track}, {"password", password}});
        }, [this](Json data) { AuthResult(data); }, L"Проверка пароля…");
    }

    std::string ContactName(int64_t id) {
        auto key = std::to_string(id);
        auto it = contacts_.find(key);
        if (it == contacts_.end()) return key;
        return PersonName(*it, key);
    }

    std::string PersonName(Json const& contact, std::string const& fallback) {
        auto names = Array(contact, "names");
        std::string custom, oneme, first;
        for (auto const& name : names) {
            if (!name.is_object()) continue;
            auto type = Text(name, "type");
            auto whole = Text(name, "name");
            auto joined = Text(name, "firstName");
            auto last = Text(name, "lastName");
            if (!last.empty()) joined = joined.empty() ? last : joined + " " + last;
            if (whole.empty() && joined.empty()) continue;
            if (whole.empty()) whole = joined;
            if (type == "CUSTOM" && custom.empty()) custom = whole;
            if (type == "ONEME" && oneme.empty()) oneme = whole;
            if (first.empty()) first = whole;
        }
        auto chosen = !custom.empty() ? custom : !oneme.empty() ? oneme : first;
        if (!chosen.empty()) return chosen;
        auto phone = Integer(contact, "phone");
        return phone ? "+" + std::to_string(phone) : fallback;
    }

    int64_t DialogPartner(Json const& chat) {
        auto participants = Object(chat, "participants");
        if (participants.is_object()) for (auto it = participants.begin(); it != participants.end(); ++it) {
            try {
                auto id = std::stoll(it.key());
                if (id && id != me_) return id;
            } catch (...) {}
        }
        auto id = Integer(chat, "id");
        return id ? id ^ me_ : INT64_C(0);
    }

    std::string ChatAvatarUrl(Json const& chat) {
        if (Text(chat, "type") == "DIALOG") {
            auto partner = DialogPartner(chat);
            if (!partner) return {};
            auto it = contacts_.find(std::to_string(partner));
            if (it != contacts_.end()) {
                auto url = FirstText(*it, {"baseUrl", "iconUrl"});
                if (!url.empty()) return url;
            }
            return {};
        }
        return FirstText(chat, {"baseIconUrl", "baseUrl", "iconUrl"});
    }

    void FetchPresence() {
        if (!online_ || presence_fetching_ || Now() < last_presence_fetch_ + 30000) return;
        Json ids = Json::array();
        std::set<int64_t> unique;
        for (auto const& item : chats_) {
            auto partner = DialogPartner(item);
            if (partner && partner != me_ && unique.insert(partner).second) ids.push_back(partner);
            if (ids.size() >= 128) break;
        }
        if (ids.empty()) return;
        presence_fetching_ = true;
        last_presence_fetch_ = Now();
        Launch([ids](auto session) { return session->Request(35, {{"contactIds", ids}}); }, [this](Json data) {
            presence_fetching_ = false;
            ApplyPresence(data);
            if (page_ == Page::Chats && chat_list_) RenderChats();
        });
    }

    void ApplyPresence(Json const& data) {
        auto rows = data.find("presence");
        if (rows == data.end() || !rows->is_object()) return;
        for (auto it = rows->begin(); it != rows->end(); ++it) {
            int64_t id = 0;
            try { id = std::stoll(it.key()); } catch (...) {}
            if (!id && it->is_object()) id = Integer(*it, "userId", Integer(*it, "id"));
            if (id && it->is_object()) presence_[std::to_string(id)] = *it;
        }
        UpdateConversationPresence();
    }

    void ApplyPresenceUpdate(Json const& payload) {
        if (!payload.is_object()) return;
        auto entry = Object(payload, "presence");
        auto id = Integer(payload, "userId", Integer(payload, "id"));
        if (!id && entry.is_object()) id = Integer(entry, "userId", Integer(entry, "id"));
        if (!id) return;
        if (entry.empty()) entry = {{"status", Integer(payload, "status")}, {"seen", Integer(payload, "seen", Integer(payload, "seenTime"))}};
        presence_[std::to_string(id)] = entry;
        UpdateConversationPresence();
        if (page_ == Page::Chats && chat_list_) RenderChats();
    }

    std::string PresenceText(int64_t id) {
        if (!id) return {};
        auto it = presence_.find(std::to_string(id));
        if (it == presence_.end() || !it->is_object()) return "статус не указан";
        if (Integer(*it, "status") == 1) return "в сети";
        auto seen = Integer(*it, "seen", Integer(*it, "seenTime"));
        if (seen <= 0) return "не в сети";
        time_t seconds = time_t(seen / 1000);
        tm local{};
        localtime_s(&local, &seconds);
        wchar_t buffer[48]{};
        wcsftime(buffer, 48, L"был(а) в сети %d.%m в %H:%M", &local);
        return to_string(hstring(buffer));
    }

    void ResetHeaderAvatar() {
        if (!header_avatar_) return;
        header_avatar_.Visibility(Visibility::Collapsed);
        subtitle_.Text(L"");
        subtitle_.Visibility(Visibility::Collapsed);
    }

    void SetHeaderAvatar(std::string const& url, wchar_t fallback, std::string const& subtitle) {
        if (!header_avatar_) return;
        header_avatar_.Child(Avatar(url, fallback ? hstring(std::wstring(1, fallback)) : L"?"));
        header_avatar_.Visibility(Visibility::Visible);
        subtitle_.Text(to_hstring(subtitle));
        subtitle_.Visibility(subtitle.empty() ? Visibility::Collapsed : Visibility::Visible);
    }

    void UpdateConversationPresence() {
        if (!subtitle_) return;
        std::string text;
        if (page_ == Page::Conversation) {
            for (auto const& item : chats_) if (Integer(item, "id") == chat_) {
                text = PresenceText(DialogPartner(item));
                break;
            }
        }
        subtitle_.Text(to_hstring(text));
        subtitle_.Visibility(text.empty() ? Visibility::Collapsed : Visibility::Visible);
    }

    void ShowConversationHeader() {
        if (page_ != Page::Conversation) return;
        for (auto const& item : chats_) if (Integer(item, "id") == chat_) {
            auto title = to_hstring(ChatTitle(item));
            auto wide = std::wstring(title.c_str());
            wchar_t initial = wide.empty() ? L'?' : wide.front();
            if (Text(item, "type") == "DIALOG" && !Integer(item, "id")) initial = L'★';
            SetHeaderAvatar(ChatAvatarUrl(item), initial, chat_ == 0 ? "Сообщения себе" : PresenceText(DialogPartner(item)));
            return;
        }
    }

    void OpenChatProfile() {
        if (page_ != Page::Conversation) return;
        if (chat_ == 0) { ShowProfile(); return; }
        for (auto const& item : chats_) if (Integer(item, "id") == chat_) {
            if (Text(item, "type") == "DIALOG" && DialogPartner(item)) {
                ContactDetails(DialogPartner(item));
                return;
            }
            break;
        }
        ChatInfo();
    }

    std::string ChatTitle(Json const& chat) {
        if (chat.contains("id") && Integer(chat, "id") == 0) return "Избранное";
        auto title = Text(chat, "title");
        if (!title.empty()) return title;
        auto participants = Object(chat, "participants");
        if (participants.is_object()) for (auto it = participants.begin(); it != participants.end(); ++it) {
            try {
                auto id = std::stoll(it.key());
                if (id && id != me_) return ContactName(id);
            } catch (...) {}
        }
        if (Text(chat, "type") == "DIALOG") {
            auto id = Integer(chat, "id");
            if (id == 0) return "Избранное";
            return ContactName(DialogPartner(chat));
        }
        return "Чат " + std::to_string(Integer(chat, "id"));
    }

    std::string LastMessagePreview(Json const& message) {
        auto text = Text(message, "text");
        if (!text.empty()) return text;
        for (auto const& attach : Array(message, "attaches")) {
            auto type = Text(attach, "_type");
            if (type == "PHOTO") return "Фотография";
            if (type == "STICKER") return "Стикер";
            if (type == "VIDEO") return "Видео";
            if (type == "AUDIO") return "Аудио";
            if (type == "FILE") return Text(attach, "name", "Файл");
            if (type == "POLL") return "Опрос";
        }
        return Text(message, "text", "Вложение или служебное сообщение");
    }

    void RenderChats() {
        EnsureSavedChat(chats_);
        chat_list_.Items().Clear();
        auto filter = to_string(search_.Text());
        auto lower = [](std::string const& text) {
            auto wide = to_hstring(text);
            std::wstring out(wide.c_str());
            std::transform(out.begin(), out.end(), out.begin(), towlower);
            return out;
        };
        std::stable_sort(chats_.begin(), chats_.end(), [](Json const& a, Json const& b) {
            if (Integer(a, "id") == 0 || Integer(b, "id") == 0) return Integer(a, "id") == 0 && Integer(b, "id") != 0;
            return Integer(a, "lastEventTime", Integer(Object(a, "lastMessage"), "time")) >
                   Integer(b, "lastEventTime", Integer(Object(b, "lastMessage"), "time"));
        });
        for (auto const& chat : chats_) {
            auto title = ChatTitle(chat);
            if (!filter.empty() && lower(title).find(lower(filter)) == std::wstring::npos) continue;
            Grid row;
            row.Margin(Thickness{12, 10, 12, 10});
            ColumnDefinition picture;
            picture.Width(GridLengthHelper::Auto());
            row.ColumnDefinitions().Append(picture);
            row.ColumnDefinitions().Append(ColumnDefinition());
            row.HorizontalAlignment(HorizontalAlignment::Stretch);
            row.Children().Append(Avatar(ChatAvatarUrl(chat), Integer(chat, "id") == 0 ? L"★" : to_hstring(title)));
            StackPanel texts;
            texts.Margin(Thickness{12, 0, 0, 0});
            texts.VerticalAlignment(VerticalAlignment::Center);
            auto unread = Integer(chat, "newMessages");
            auto name = Label(to_hstring(title) + (unread ? L"  · " + to_hstring(unread) : L""), 19);
            name.MaxLines(1);
            name.TextTrimming(TextTrimming::CharacterEllipsis);
            texts.Children().Append(name);
            auto last = Object(chat, "lastMessage");
            auto receipt = Integer(last, "sender") == me_ ? ReadByOthers(chat, last, me_) ? L"✓✓ " : L"✓ " : L"";
            auto preview = Label(hstring(receipt) + to_hstring(LastMessagePreview(last)));
            if (Text(chat, "type") == "DIALOG" && Integer(chat, "id") != 0) {
                auto state = PresenceText(DialogPartner(chat));
                auto presence = Label(to_hstring(state), 12);
                presence.Opacity(state == "в сети" ? 1 : 0.65);
                if (state == "в сети") presence.Foreground(ResourceBrush(L"SystemControlHighlightAccentBrush"));
                texts.Children().Append(presence);
            }
            preview.MaxLines(2);
            preview.Opacity(0.65);
            texts.Children().Append(preview);
            Grid::SetColumn(texts, 1);
            row.Children().Append(texts);
            row.Tag(box_value(Integer(chat, "id")));
            chat_list_.Items().Append(row);
        }
    }

    void ShowChats() {
        PageStart(Page::Chats, L"Чаты");
        Grid layout;
        RowDefinition top;
        top.Height(GridLengthHelper::Auto());
        layout.RowDefinitions().Append(top);
        layout.RowDefinitions().Append(RowDefinition());
        search_ = TextBox();
        search_.PlaceholderText(L"Поиск чатов");
        search_.Margin(Thickness{16, 4, 16, 12});
        search_.TextChanged([this](auto const&, auto const&) { if (chat_list_) RenderChats(); });
        layout.Children().Append(search_);
        chat_list_ = ListView();
        Style chat_style(xaml_typename<ListViewItem>());
        chat_style.Setters().Append(Setter(Control::HorizontalContentAlignmentProperty(), box_value(HorizontalAlignment::Stretch)));
        chat_list_.ItemContainerStyle(chat_style);
        chat_list_.SelectionMode(ListViewSelectionMode::None);
        chat_list_.IsItemClickEnabled(true);
        chat_list_.ItemClick([this](auto const&, ItemClickEventArgs const& args) {
            if (busy_) return;
            auto item = args.ClickedItem().as<FrameworkElement>();
            chat_ = unbox_value<int64_t>(item.Tag());
            ShowConversation();
            LoadHistory(false);
        });
        Grid::SetRow(chat_list_, 1);
        layout.Children().Append(chat_list_);
        content_.Children().Append(layout);
        if (marker_ > 0) AddCommand(Symbol::More, L"Ещё чаты", [this] { MoreChats(); });
        AddCommand(Symbol::Favorite, L"Избранное", [this] { if (busy_) return; chat_ = 0; ShowConversation(); LoadHistory(false); });
        AddCommand(Symbol::Contact, L"Профиль", [this] { ShowProfile(); });
        AddCommand(Symbol::Find, L"Найти", [this] { SearchGlobal(); }, true);
        AddCommand(Symbol::Add, L"Создать чат", [this] { CreateGroup(); }, true);
        AddCommand(Symbol::Link, L"Вступить по ссылке", [this] { JoinChat(); }, true);
        RenderChats();
        if (chats_.empty()) Status(L"Чатов пока нет. Нажмите «Обновить».");
    }

    void MoreChats() {
        if (!online_ || marker_ <= 0) return;
        auto marker = marker_;
        Run([marker](auto session) { return session->Request(53, {{"marker", marker}, {"count", 50}}); },
            [this, marker](Json data) {
                ApplyContacts(data);
                ApplyPresence(data);
                auto rows = Array(data, "chats");
                if (rows.is_array()) for (auto const& item : rows) {
                    auto id = Integer(item, "id");
                    auto found = std::find_if(chats_.begin(), chats_.end(), [id](Json const& c) { return Integer(c, "id") == id; });
                    if (found == chats_.end()) chats_.push_back(item); else *found = item;
                }
                auto next = Integer(data, "marker");
                marker_ = next != marker && !rows.empty() ? next : 0;
                ResolveNames();
                ShowChats();
            }, L"Загрузка чатов…");
    }

    void ShowConversation() {
        hstring title = L"Переписка";
        for (auto const& item : chats_) if (Integer(item, "id") == chat_) title = to_hstring(ChatTitle(item));
        PageStart(Page::Conversation, title, false);
        ShowConversationHeader();
        messages_ = history_cache_.value(std::to_string(chat_), Json::array());
        Grid layout;
        RowDefinition top;
        top.Height(GridLengthHelper::Auto());
        layout.RowDefinitions().Append(top);
        layout.RowDefinitions().Append(RowDefinition());
        RowDefinition bottom;
        bottom.Height(GridLengthHelper::Auto());
        layout.RowDefinitions().Append(bottom);
        auto older = ButtonWith(L"Предыдущие сообщения", [this] { LoadHistory(true); });
        older.Margin(Thickness{12, 0, 12, 4});
        layout.Children().Append(older);
        message_list_ = ListView();
        Style message_style(xaml_typename<ListViewItem>());
        message_style.Setters().Append(Setter(Control::HorizontalContentAlignmentProperty(), box_value(HorizontalAlignment::Stretch)));
        message_list_.ItemContainerStyle(message_style);
        ScrollViewer::SetVerticalScrollMode(message_list_, ScrollMode::Enabled);
        ScrollViewer::SetHorizontalScrollMode(message_list_, ScrollMode::Disabled);
        message_list_.SelectionMode(ListViewSelectionMode::None);
        message_list_.IsItemClickEnabled(true);
        message_list_.ItemClick([this](auto const&, ItemClickEventArgs const& args) {
            auto item = args.ClickedItem().as<FrameworkElement>();
            auto id = unbox_value<int64_t>(item.Tag());
            for (auto const& message : messages_) if (Integer(message, "id") == id) { MessageMenu(item, message); break; }
        });
        Grid::SetRow(message_list_, 1);
        layout.Children().Append(message_list_);
        Grid compose;
        compose.Margin(Thickness{8, 6, 8, 8});
        ColumnDefinition left;
        left.Width(GridLengthHelper::Auto());
        compose.ColumnDefinitions().Append(left);
        compose.ColumnDefinitions().Append(ColumnDefinition());
        ColumnDefinition right;
        right.Width(GridLengthHelper::Auto());
        compose.ColumnDefinitions().Append(right);
        Button attach;
        attach.Content(SymbolIcon(Symbol::Attach));
        attach.Width(40);
        attach.Height(44);
        attach.Padding(Thickness{4});
        attach.Margin(Thickness{0, 0, 4, 0});
        attach.VerticalAlignment(VerticalAlignment::Bottom);
        ToolTipService::SetToolTip(attach, box_value(L"Прикрепить"));
        MenuFlyout menu;
        auto attachment = [&](hstring const& name, std::function<void()> action) {
            MenuFlyoutItem item;
            item.Text(name);
            item.Click([action](auto const&, auto const&) { action(); });
            menu.Items().Append(item);
        };
        attachment(L"Файл", [this] { PickFile(); });
        attachment(L"Фото", [this] { PickPhoto(false); });
        attachment(L"Камера", [this] { TakePhoto(); });
        attachment(L"Аудиофайл", [this] { PickFile(true); });
        attachment(L"Стикер", [this] { ShowStickers(); });
        attach.Flyout(menu);
        compose.Children().Append(attach);
        composer_ = TextBox();
        composer_.PlaceholderText(L"Сообщение");
        composer_.AcceptsReturn(true);
        composer_.TextWrapping(TextWrapping::Wrap);
        composer_.MaxLength(4000);
        composer_.MaxHeight(120);
        composer_.Text(drafts_[chat_]);
        composer_.TextChanged([this](auto const&, auto const&) { drafts_[chat_] = composer_.Text(); cache_dirty_ = true; });
        Grid::SetColumn(composer_, 1);
        compose.Children().Append(composer_);
        Button send;
        send.Content(SymbolIcon(Symbol::Send));
        send.MinWidth(48);
        send.MinHeight(44);
        send.Margin(Thickness{8, 0, 0, 0});
        send.VerticalAlignment(VerticalAlignment::Bottom);
        send.Click([this](auto const&, auto const&) { SendMessage(); });
        Grid::SetColumn(send, 2);
        compose.Children().Append(send);
        Grid::SetRow(compose, 2);
        layout.Children().Append(compose);
        content_.Children().Append(layout);

        AddCommand(Symbol::Download, L"В конец чата", [this] { ScrollToLatest(); }, true);
        AddCommand(Symbol::Refresh, L"Обновить", [this] { Refresh(); }, true);
        AddCommand(Symbol::Camera, L"Камера", [this] { TakePhoto(); }, true);
        AddCommand(Symbol::Emoji, L"Стикеры", [this] { ShowStickers(); }, true);
        AddCommand(Symbol::List, L"Создать опрос", [this] { CreatePoll(); }, true);
        AddCommand(Symbol::Clock, L"Отправить позже", [this] { ScheduleMessage(); }, true);
        AddCommand(Symbol::Find, L"Поиск сообщений", [this] { SearchMessages(); }, true);
        AddCommand(Symbol::ContactInfo, L"О чате", [this] { ChatInfo(); }, true);
        AddCommand(Symbol::Accept, L"Отметить прочитанным", [this] { MarkRead(); }, true);
        AddCommand(Symbol::Cancel, L"Отменить ответ", [this] { reply_id_ = 0; composer_.Header(nullptr); }, true);
        RenderMessages(true);
    }

    void ScrollToLatest() {
        if (!message_list_ || !message_list_.Items().Size()) return;
        auto list = message_list_;
        list.Dispatcher().RunAsync(CoreDispatcherPriority::Low, [list] {
            if (!list.Items().Size()) return;
            list.UpdateLayout();
            list.ScrollIntoView(list.Items().GetAt(list.Items().Size() - 1));
            list.UpdateLayout();
            if (auto viewer = VisualChild<ScrollViewer>(list)) {
                viewer.ChangeView(nullptr, box_value(viewer.ScrollableHeight()).as<Windows::Foundation::IReference<double>>(), nullptr, true);
            }
        });
    }

    hstring DeliveryStatus(Json const& message) {
        if (chat_ == 0) return L"✓ Сохранено";
        for (auto const& item : chats_) if (Integer(item, "id") == chat_) return ReadByOthers(item, message, me_) ? L"✓✓ Прочитано" : L"✓ Отправлено";
        return L"✓ Отправлено";
    }

    void ApplyReadMark(Json const& payload) {
        if (!MergeReadMark(chats_, payload)) return;
        cache_dirty_ = true;
        if (page_ == Page::Chats && chat_list_) RenderChats();
        if (page_ == Page::Conversation && Integer(payload, "chatId") == chat_) {
            for (auto const& message : messages_) {
                auto it = delivery_labels_.find(Integer(message, "id"));
                if (it != delivery_labels_.end()) it->second.Text(DeliveryStatus(message));
            }
        }
    }

    void MarkVisibleRead() {
        if (chat_ == 0 || !online_ || marking_read_ || anti_read_ || page_ != Page::Conversation || !message_list_ || messages_.empty()) return;
        auto viewer = VisualChild<ScrollViewer>(message_list_);
        if (!viewer || viewer.ScrollableHeight() - viewer.VerticalOffset() > 64) return;
        auto message = messages_.back();
        auto mark = Integer(message, "time");
        if (mark <= read_marks_[chat_]) return;
        auto chat = chat_;
        marking_read_ = true;
        Launch([chat, mark, message](auto session) { session->Request(50, {{"type", "READ_MESSAGE"}, {"chatId", chat}, {"messageId", Integer(message, "id")}, {"mark", mark}}); return Json(true); }, [this, chat, mark](Json data) {
            marking_read_ = false;
            if (data != Json(true)) return;
            read_marks_[chat] = mark;
            ApplyReadMark({{"chatId", chat}, {"userId", me_}, {"mark", mark}});
            for (auto& item : chats_) if (Integer(item, "id") == chat) item["newMessages"] = 0;
        });
    }

    void RenderMessages(bool scroll, bool prepend = false) {
        if (!message_list_) return;
        auto viewer = VisualChild<ScrollViewer>(message_list_);
        auto offset = viewer ? viewer.VerticalOffset() : 0;
        auto extent = viewer ? viewer.ExtentHeight() : 0;
        auto list = message_list_;
        auto items = message_list_.Items();
        uint32_t index = 0;
        std::set<int64_t> retained;
        for (auto const& message : messages_) {
            auto id = Integer(message, "id");
            Json revision = {{"message", message}, {"name", ContactName(Integer(message, "sender"))}};
            retained.insert(id);
            if (index < items.Size() && unbox_value<int64_t>(items.GetAt(index).as<FrameworkElement>().Tag()) != id) {
                for (uint32_t candidate = index + 1; candidate < items.Size(); ++candidate) {
                    if (unbox_value<int64_t>(items.GetAt(candidate).as<FrameworkElement>().Tag()) != id) continue;
                    auto obsolete = candidate - index;
                    while (obsolete--) items.RemoveAt(index);
                    break;
                }
            }
            if (index < items.Size() && unbox_value<int64_t>(items.GetAt(index).as<FrameworkElement>().Tag()) == id && rendered_messages_.count(id) && rendered_messages_.at(id) == revision) {
                ++index;
                continue;
            }
            StackPanel body;
            body.Margin(Thickness{12, 8, 12, 8});
            auto sender = Integer(message, "sender");
            auto caption = Label(sender == me_ ? L"Вы" : to_hstring(ContactName(sender)), 12);
            caption.Opacity(0.65);
            body.Children().Append(caption);
            auto link = Object(message, "link");
            if (link.is_object() && !Text(link, "type").empty()) body.Children().Append(Label(Text(link, "type") == "REPLY" ? L"Ответ на сообщение" : L"Пересланное сообщение", 12));
            auto text = Text(message, "text");
            if (!text.empty()) { auto block = Label(to_hstring(text), 17); block.IsTextSelectionEnabled(true); body.Children().Append(block); }
            RenderAttachments(body, message);
            RenderReactions(body, message);
            auto stamp = Integer(message, "time");
            if (stamp > 0) {
                time_t seconds = time_t(stamp / 1000);
                tm local{};
                localtime_s(&local, &seconds);
                wchar_t buffer[32]{};
                wcsftime(buffer, 32, L"%d.%m %H:%M", &local);
                auto date = Label(buffer, 12);
                date.Opacity(0.5);
                body.Children().Append(date);
            }
            if (sender == me_) {
                auto delivery = Label(DeliveryStatus(message), 12);
                delivery.Opacity(0.7);
                body.Children().Append(delivery);
                delivery_labels_.insert_or_assign(id, delivery);
            }
            Border bubble;
            bubble.Child(body);
            bubble.CornerRadius(CornerRadius{4});
            bubble.BorderThickness(Thickness{3, 0, 0, 0});
            bubble.BorderBrush(ResourceBrush(sender == me_ ? L"SystemControlHighlightAccentBrush" : L"SystemControlForegroundBaseMediumLowBrush"));
            bubble.Margin(sender == me_ ? Thickness{32, 4, 0, 4} : Thickness{0, 4, 32, 4});
            bubble.Tag(box_value(Integer(message, "id")));
            if (index < items.Size() && unbox_value<int64_t>(items.GetAt(index).as<FrameworkElement>().Tag()) == id) items.SetAt(index, bubble);
            else items.InsertAt(index, bubble);
            rendered_messages_[id] = std::move(revision);
            ++index;
        }
        while (items.Size() > index) items.RemoveAtEnd();
        for (auto it = rendered_messages_.begin(); it != rendered_messages_.end();) {
            if (!retained.count(it->first)) { delivery_labels_.erase(it->first); it = rendered_messages_.erase(it); } else ++it;
        }
        if (scroll) ScrollToLatest();
        else if (viewer) list.Dispatcher().RunAsync(CoreDispatcherPriority::Low, [list, viewer, offset, extent, prepend] {
            list.UpdateLayout();
            viewer.ChangeView(nullptr, box_value(offset + (prepend ? viewer.ExtentHeight() - extent : 0)).as<Windows::Foundation::IReference<double>>(), nullptr, true);
        });
    }

    Json History(std::shared_ptr<Session> const& session, int64_t chat, int64_t from) {
        return session->Request(49, {{"chatId", chat}, {"from", from}, {"forward", 0}, {"backward", 50}, {"getMessages", true}});
    }

    void ApplyHistory(Json const& data, bool older) {
        auto rows = Array(data, "messages");
        if (!rows.is_array()) throw std::runtime_error("Некорректный ответ истории");
        if (!older) messages_ = Json::array();
        for (auto const& message : rows) {
            auto id = message.find("id");
            if (id == message.end()) continue;
            auto found = std::find_if(messages_.begin(), messages_.end(), [&](Json const& existing) { return existing.value("id", Json(nullptr)) == *id; });
            if (found == messages_.end()) messages_.push_back(message); else *found = message;
        }
        std::stable_sort(messages_.begin(), messages_.end(), [](Json const& a, Json const& b) { return Integer(a, "time") < Integer(b, "time"); });
        RenderMessages(!older, older);
        StoreHistory();
        cache_dirty_ = true;
        ResolveNames();
        Status(rows.empty() ? L"Сообщений больше нет." : L"Подключено");
    }

    void LoadHistory(bool older) {
        if (!online_) { Status(L"Восстанавливаю соединение…"); reconnect_after_ = 0; Reconnect(); return; }
        if (older && messages_.size() >= 500) { Status(L"Достигнут лимит 500 сообщений. Откройте чат заново для сброса."); return; }
        auto chat = chat_;
        auto from = older && !messages_.empty() ? Integer(messages_.front(), "time") - 1 : Now() + 86400000;
        auto self = get_strong();
        Run([self, chat, from](auto session) { return self->History(session, chat, from); },
            [this, chat, older](Json data) { if (page_ == Page::Conversation == chat) ApplyHistory(data, older); }, L"Загрузка сообщений…");
    }

    void SendMessage() {
        auto pending_text = composer_.Text();
        if (!RequireOnline([this, pending_text] { if (composer_ && composer_.Text() == pending_text) SendMessage(); })) return;
        auto text = to_string(composer_.Text());
        if (text.empty() || text.find_first_not_of(" \t\r\n") == std::string::npos) return;
        auto chat = chat_;
        auto cid = -Now();
        auto reply = reply_id_;
        Run([chat, cid, text, reply](auto session) {
            Json message = {{"text", text}, {"cid", cid}, {"elements", Json::array()}, {"attaches", Json::array()}};
            if (reply) message["link"] = {{"type", "REPLY"}, {"chatId", chat}, {"messageId", reply}};
            auto result = session->Request(64, {{"chatId", chat}, {"notify", true}, {"message", message}});
            if (!result.is_object() || !result.contains("message")) throw std::runtime_error("Нет подтверждения отправки. Обновите историю.");
            return result;
        }, [this](Json data) {
            composer_.Text(L"");
            reply_id_ = 0;
            composer_.Header(nullptr);
            auto message = data.at("message");
            messages_.push_back(message);
            if (messages_.size() > 500) messages_.erase(messages_.begin());
            RenderMessages(true);
            StoreHistory();
            cache_dirty_ = true;
            Status(L"Сообщение отправлено");
        }, L"Отправка…");
    }

    void Refresh() {
        if (busy_) return;
        if (!online_) { Connect(); return; }
        if (page_ == Page::Conversation) { LoadHistory(false); return; }
        auto self = get_strong();
        auto token = token_;
        Run([self, token](auto session) { return self->Login(session, token); },
            [this](Json data) { ApplyLogin(data); }, L"Обновление чатов…");
    }

    void AutoReload() {
        auto chat = chat_;
        auto self = get_strong();
        auto current = session_;
        auto generation = generation_;
        auto dispatcher = Window::Current().Dispatcher();
        std::thread([self, current, generation, dispatcher, chat] {
            init_apartment(apartment_type::multi_threaded);
            Json data;
            try { data = self->History(current, chat, Now() + 86400000); } catch (...) { return; }
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, generation, chat, data = std::move(data)] {
                if (generation != self->generation_ || self->suspended_ || self->chat_ != chat) return;
                auto rows = Array(data, "messages");
                if (!rows.is_array()) return;
                if (rows.size() == self->messages_.size()) {
                    bool same = true;
                    for (size_t i = 0; i < rows.size(); ++i) {
                        if (Integer(rows[i], "id") != Integer(self->messages_[i], "id")) { same = false; break; }
                    }
                    if (same) return;
                }
                if (self->page_ != Page::Conversation || !self->message_list_) return;
                auto viewer = VisualChild<ScrollViewer>(self->message_list_);
                bool follow = !viewer || viewer.ScrollableHeight() - viewer.VerticalOffset() < 80;
                try {
                    auto merged = self->messages_;
                    for (auto const& row : rows) {
                        auto found = std::find_if(merged.begin(), merged.end(), [&](Json const& item) { return Integer(item, "id") == Integer(row, "id"); });
                        if (found == merged.end()) merged.push_back(row); else *found = row;
                    }
                    std::stable_sort(merged.begin(), merged.end(), [](Json const& a, Json const& b) { return Integer(a, "time") < Integer(b, "time"); });
                    while (merged.size() > 500) merged.erase(merged.begin());
                    self->messages_ = std::move(merged);
                    self->RenderMessages(follow);
                    self->StoreHistory();
                    self->cache_dirty_ = true;
                    self->ResolveNames();
                } catch (...) {}
            });
        }).detach();
    }

    void AutoRefresh() {
        if (busy_ || !session_ || !online_) return;
        auto self = get_strong();
        if (page_ == Page::Conversation) { AutoReload(); return; }
        auto token = token_;
        auto current = session_;
        auto generation = generation_;
        auto dispatcher = Window::Current().Dispatcher();
        std::thread([self, current, generation, dispatcher, token] {
            init_apartment(apartment_type::multi_threaded);
            Json data;
            try { data = self->Login(current, token); } catch (...) { return; }
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, generation, data = std::move(data)] {
                if (generation != self->generation_ || self->suspended_) return;
                try { self->ApplyLogin(data, true); } catch (...) {}
            });
        }).detach();
    }

    void Back() {
        if (busy_) return;
        if ((page_ == Page::Tools || page_ == Page::About) && tools_return_conversation_) { ShowConversation(); return; }
        if (page_ == Page::Conversation || page_ == Page::About || page_ == Page::Tools) {
            chat_ = 0;
            if (!token_.empty()) ShowChats();
            else ShowLogin();
        }
    }

    void ShowAbout() {
        PageStart(Page::About, L"О приложении");
        StackPanel panel;
        panel.Margin(Thickness{20, 12, 20, 24});
        panel.Children().Append(Label(L"Komet для Windows 10 Mobile", 24));
        panel.Children().Append(Label(L"0.2.6.0 · ARM32 · UWP\n\nНативный интерфейс: системная тема, акцент Windows, нижняя панель команд и аппаратная кнопка «Назад».\n\nВ 0.2.4: компактная скрепка слева от поля ввода, Play/Pause для аудио и видео, встроенный декодер голосовых Ogg/Opus, исправленные аватарки, сохранение проигрывателя при обновлении истории и устранение ложных отключений по тайм-ауту ping. Журнал соединения находится в настройках.\n\nРанее: фотографии и стикеры в переписке, настоящие имена собеседников, тихое восстановление соединения с паузами вместо циклического переподключения, кнопка «Назад» не выкидывает на экран входа, пока есть сохранённый аккаунт.\n\nВход по коду, QR и паролю, чаты, история, отправка, ответы, пересылка, реакции, файлы, группы, контакты и опросы перенесены. Это предварительный порт: звонки, фоновые push, истории и мини-приложения отсутствуют.\n\nИсходный проект: github.com/KometTeam/Komet\nGPL-3.0. nlohmann/json и Project Nayuki QR: MIT. LZ4: BSD-2-Clause, Zstandard: BSD-3-Clause."));
        panel.Children().Append(Label(L"\nСемейство: " + Windows::System::Profile::AnalyticsInfo::VersionInfo().DeviceFamily()));
        ScrollViewer scroll;
        scroll.Content(panel);
        content_.Children().Append(scroll);
    }

    void Logout() {
        if (busy_) return;
        ContentDialog confirm;
        confirm.Title(box_value(L"Выйти из Komet?"));
        confirm.Content(box_value(L"Токен входа будет удалён с этого устройства. Для повторного входа понадобится код. Сессию на сервере можно завершить в официальном MAX."));
        confirm.PrimaryButtonText(L"Выйти");
        confirm.SecondaryButtonText(L"Отмена");
        auto weak = get_weak();
        auto dispatcher = Window::Current().Dispatcher();
        confirm.ShowAsync().Completed([weak, dispatcher](auto const& operation, auto state) {
            if (state != Windows::Foundation::AsyncStatus::Completed) return;
            if (operation.GetResults() != ContentDialogResult::Primary) return;
            if (auto self = weak.get()) {
                dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self] {
                    try {
                        PasswordVault vault;
                        try { vault.Remove(vault.Retrieve(L"KometW10M", L"session")); }
                        catch (hresult_error const& e) { if (e.code() != HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) throw; }
                        try { vault.Remove(vault.Retrieve(L"KometW10M", L"account:" + to_hstring(self->me_))); }
                        catch (hresult_error const& e) { if (e.code() != HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) throw; }
                        ++self->generation_;
                        self->SetBusy(false);
                        if (self->session_) self->session_->Close();
                        self->session_.reset();
                        self->token_.clear();
                        self->otp_token_.clear();
                        self->track_.clear();
                        self->online_ = false;
                        self->chats_ = Json::array();
                        self->messages_ = Json::array();
                        self->contacts_ = Json::object();
                        self->drafts_.clear();
                        self->history_cache_ = Json::object();
                        self->me_ = 0;
                        self->cache_dirty_ = false;
                        Cache::Invalidate();
                        std::thread([] { init_apartment(apartment_type::multi_threaded); try { Cache::Clear(); } catch (...) {} }).detach();
                        self->ShowLogin();
                        self->Status(L"Вы вышли из приложения.");
                    } catch (hresult_error const& e) { self->Status(L"Не удалось удалить токен: " + e.message()); }
                });
            }
        });
    }

    void OnBackgroundActivated(Windows::ApplicationModel::Activation::BackgroundActivatedEventArgs const& args) {
        background_->Run(args.TaskInstance());
    }

    fire_and_forget SetupBackground() {
        auto self = get_strong();
        try { co_await background_->Configure(); }
        catch (hresult_error const& e) { LogConn(L"Фон: " + e.message()); BackgroundService::Log(e.message()); }
    }

    void OnLaunched(Windows::ApplicationModel::Activation::LaunchActivatedEventArgs const&) {
        if (ui_ready_) {
            background_->Foreground();
            if (suspended_) { SetBusy(false); reconnecting_ = false; pinging_ = false; }
            suspended_ = false;
            Window::Current().Activate();
            timer_.Start();
            if (!token_.empty() && !online_) { reconnect_after_ = 0; Reconnect(); }
            return;
        }
        Windows::UI::ViewManagement::ApplicationView::GetForCurrentView().SetDesiredBoundsMode(Windows::UI::ViewManagement::ApplicationViewBoundsMode::UseVisible);
        for (int i = 0; i < 4; ++i) {
            RowDefinition row;
            row.Height(i == 2 ? GridLengthHelper::FromValueAndType(1, GridUnitType::Star) : GridLengthHelper::Auto());
            root_.RowDefinitions().Append(row);
        }
        root_.Background(ResourceBrush(L"ApplicationPageBackgroundThemeBrush"));
        Grid header;
        header.Margin(Thickness{16, 28, 16, 8});
        RowDefinition brand_row;
        brand_row.Height(GridLengthHelper::Auto());
        RowDefinition title_row;
        title_row.Height(GridLengthHelper::Auto());
        RowDefinition status_row;
        status_row.Height(GridLengthHelper::Auto());
        header.RowDefinitions().Append(brand_row);
        header.RowDefinitions().Append(title_row);
        header.RowDefinitions().Append(status_row);
        auto brand = Label(L"Komet", 12);
        brand.Foreground(ResourceBrush(L"SystemControlHighlightAccentBrush"));
        Grid::SetRow(brand, 0);
        header.Children().Append(brand);
        ColumnDefinition avatar_column;
        avatar_column.Width(GridLengthHelper::Auto());
        ColumnDefinition text_column;
        text_column.Width(GridLengthHelper::FromValueAndType(1, GridUnitType::Star));
        Grid title_grid;
        title_grid.ColumnDefinitions().Append(avatar_column);
        title_grid.ColumnDefinitions().Append(text_column);
        header_avatar_ = Border();
        header_avatar_.CornerRadius(CornerRadius{24});
        header_avatar_.Width(48);
        header_avatar_.Height(48);
        header_avatar_.Background(ResourceBrush(L"SystemControlBackgroundAccentBrush"));
        header_avatar_.Visibility(Visibility::Collapsed);
        header_avatar_.VerticalAlignment(VerticalAlignment::Center);
        Grid::SetColumn(header_avatar_, 0);
        title_grid.Children().Append(header_avatar_);
        {
            auto weak = get_weak();
            header_avatar_.Tapped([weak](auto const&, Input::TappedRoutedEventArgs const&) {
                if (auto self = weak.get()) self->OpenChatProfile();
            });
        }
        StackPanel texts;
        texts.VerticalAlignment(VerticalAlignment::Center);
        texts.Margin(Thickness{12, 0, 0, 0});
        title_.FontSize(23);
        title_.TextTrimming(TextTrimming::CharacterEllipsis);
        texts.Children().Append(title_);
        subtitle_ = TextBlock();
        subtitle_.FontSize(13);
        subtitle_.Foreground(ResourceBrush(L"SystemControlForegroundAccentBrush"));
        subtitle_.Margin(Thickness{0, 4, 0, 0});
        subtitle_.Visibility(Visibility::Collapsed);
        texts.Children().Append(subtitle_);
        Grid::SetColumn(texts, 1);
        title_grid.Children().Append(texts);
        Grid::SetRow(title_grid, 1);
        header.Children().Append(title_grid);
        status_.TextWrapping(TextWrapping::Wrap);
        status_.FontSize(13);
        status_.Margin(Thickness{0, 10, 0, 0});
        status_.MaxLines(2);
        Grid::SetRow(status_, 2);
        header.Children().Append(status_);
        root_.Children().Append(header);
        progress_.Visibility(Visibility::Collapsed);
        Grid::SetRow(progress_, 1);
        root_.Children().Append(progress_);
        content_host_.HorizontalContentAlignment(HorizontalAlignment::Stretch);
        content_host_.VerticalContentAlignment(VerticalAlignment::Stretch);
        content_host_.Content(content_);
        Grid::SetRow(content_host_, 2);
        root_.Children().Append(content_host_);
        Grid::SetRow(commands_, 3);
        root_.Children().Append(commands_);
        Window::Current().Content(root_);
        Window::Current().Activate();
        ui_ready_ = true;
        background_->Foreground();
        SetupBackground();
        auto weak = get_weak();
        SystemNavigationManager::GetForCurrentView().BackRequested([weak](auto const&, BackRequestedEventArgs const& args) {
            if (auto self = weak.get(); self && (self->page_ == Page::Conversation || self->page_ == Page::About || self->page_ == Page::Tools)) {
                args.Handled(true);
                self->Back();
            }
        });
        EnteredBackground([weak](auto const&, auto const&) { if (auto self = weak.get()) self->background_->foreground = false; });
        LeavingBackground([weak](auto const&, auto const&) {
            if (auto self = weak.get()) {
                self->background_->Foreground();
                if (!self->suspended_ && !self->online_ && !self->token_.empty()) { self->reconnect_after_ = 0; self->Reconnect(); }
            }
        });
        Suspending([weak](auto const&, Windows::ApplicationModel::SuspendingEventArgs const& args) {
            if (auto self = weak.get()) {
                self->suspended_ = true;
                self->background_->foreground = false;
                ++self->generation_;
                self->timer_.Stop();
                self->qr_timer_.Stop();
                self->qr_track_.clear();
                self->SaveCache(args.SuspendingOperation().GetDeferral());
                if (self->session_) self->session_->Close();
                self->online_ = false;
                self->otp_token_.clear();
                self->track_.clear();
                if (!self->token_.empty()) self->background_->Start();
            }
        });
        auto dispatcher = Window::Current().Dispatcher();
        Resuming([weak, dispatcher](auto const&, auto const&) {
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [weak] {
                if (auto self = weak.get()) {
                    self->background_->Foreground();
                    self->suspended_ = false;
                    self->reconnecting_ = false;
                    self->pinging_ = false;
                    self->reconnect_after_ = 0;
                    self->SetBusy(false);
                    self->timer_.Start();
                    if (!self->token_.empty()) self->Reconnect();
                    else { self->ShowLogin(); self->Status(L"Запросите новый код после возвращения в приложение."); }
                }
            });
        });
        timer_.Interval(std::chrono::seconds(2));
        timer_.Tick([weak](auto const&, auto const&) {
            if (auto self = weak.get(); self && !self->busy_ && !self->suspended_) {
                self->MarkVisibleRead();
                if (self->page_ == Page::Chats || self->page_ == Page::Conversation) self->FetchPresence();
            }
            if (auto self = weak.get(); self && self->cache_dirty_ && !self->cache_saving_) self->SaveCache();
            if (auto self = weak.get(); self && !self->token_.empty() && !self->online_ && !self->busy_ && !self->reconnecting_ && !self->suspended_ &&
                self->otp_token_.empty() && self->track_.empty() && self->qr_track_.empty() && Now() >= self->reconnect_after_) {
                self->reconnect_after_ = Now() + 30000;
                self->Reconnect();
            }
            if (auto self = weak.get(); self && !self->reconnecting_ && self->session_ &&
                (self->online_ || !self->otp_token_.empty() || !self->track_.empty() || !self->qr_track_.empty())) {
                if (!self->busy_ && self->online_ && self->dirty_ && self->page_ != Page::About && self->page_ != Page::Tools &&
                    (self->page_ != Page::Conversation || self->composer_.Text().empty()) && Now() >= self->last_auto_refresh_ + 15000) {
                    self->dirty_ = false;
                    self->last_auto_refresh_ = Now();
                    self->AutoRefresh();
                }
                if (++self->ticks_ >= 5) {
                    self->ticks_ = 0;
                    self->Heartbeat();
                }
            }
        });
        timer_.Start();
        qr_timer_.Tick([weak](auto const&, auto const&) { if (auto self = weak.get()) self->PollQr(); });
        ShowLoading();
        try {
            LoadIdentity();
            if (token_.empty()) { ShowLogin(); Status(L"Войдите в аккаунт"); }
            else LoadCacheThenConnect();
        } catch (hresult_error const& e) { if (token_.empty()) ShowLogin(); else ShowChats(); Status(L"Ошибка загрузки: " + e.message()); }
        catch (std::exception const& e) { if (token_.empty()) ShowLogin(); else ShowChats(); Status(to_hstring(e.what())); }
    }

#include "App.Features.inl"

    void Heartbeat() {
        if (pinging_ || !session_) return;
        pinging_ = true;
        auto self = get_strong();
        auto session = session_;
        auto generation = generation_;
        auto dispatcher = Window::Current().Dispatcher();
        auto interactive = !ghost_;
        std::thread([self, session, generation, dispatcher, interactive] {
            init_apartment(apartment_type::multi_threaded);
            bool alive = true;
            try { session->Ping(interactive); } catch (...) { alive = false; }
            dispatcher.RunAsync(CoreDispatcherPriority::Normal, [self, session, generation, alive] {
                self->pinging_ = false;
                if (generation != self->generation_ || session != self->session_ || self->suspended_) return;
                if (alive) {
                    if (self->online_) self->fail_count_ = 0;
                } else {
                    self->online_ = false;
                    self->reconnect_after_ = Now();
                    self->Status(L"Соединение потеряно. Подключаюсь заново…");
                }
            });
        }).detach();
    }
};
}

int __stdcall wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    init_apartment(apartment_type::multi_threaded);
    Application::Start([](auto const&) { make<komet::App>(); });
    return 0;
}
