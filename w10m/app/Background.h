#pragma once
#include "Session.h"
#include "Cache.h"
#include <winrt/Windows.ApplicationModel.Background.h>
#include <winrt/Windows.ApplicationModel.Activation.h>
#include <winrt/Windows.Security.Credentials.h>
#include <winrt/Windows.UI.Notifications.h>
#include <winrt/Windows.Data.Xml.Dom.h>
#include <atomic>

namespace komet {
inline int64_t BackgroundNow() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
}
inline bool BackgroundEnabled() {
    auto values = winrt::Windows::Storage::ApplicationData::Current().LocalSettings().Values();
    return !values.HasKey(L"backgroundEnabled") || winrt::unbox_value<bool>(values.Lookup(L"backgroundEnabled"));
}
inline void NotifyMessage(Json const& message, int64_t chat, int64_t me, Json const& snapshot) {
    if (!message.is_object() || !chat || !me) return;
    auto values = winrt::Windows::Storage::ApplicationData::Current().LocalSettings().Values();
    if (values.HasKey(L"notificationsEnabled") && !winrt::unbox_value<bool>(values.Lookup(L"notificationsEnabled"))) return;
    auto time = Integer(message, "time");
    auto key = L"notified:" + winrt::to_hstring(me) + L":" + winrt::to_hstring(chat);
    if (time <= 0 || Integer(message, "sender") == me) return;
    if (values.HasKey(key) && winrt::unbox_value<int64_t>(values.Lookup(key)) >= time) return;
    std::string title = "Komet";
    for (auto const& item : Array(snapshot, "chats")) if (Integer(item, "id") == chat) {
        if (Integer(item, "muteUntil") > BackgroundNow()) return;
        title = Text(item, "title", title);
        if (title == "Komet" && Text(item, "type") == "DIALOG") {
            auto contacts = Object(snapshot, "contacts");
            auto contact = Object(contacts, std::to_string(Integer(message, "sender")).c_str());
            for (auto const& name : Array(contact, "names")) { auto value = Text(name, "name", Text(name, "firstName")); if (!value.empty()) { title = value; break; } }
        }
        break;
    }
    bool preview = !values.HasKey(L"notificationPreview") || winrt::unbox_value<bool>(values.Lookup(L"notificationPreview"));
    auto text = preview ? Text(message, "text", "Новое вложение") : "Новое сообщение";
    if (text.empty()) text = "Новое вложение";
    using namespace winrt::Windows::Data::Xml::Dom;
    XmlDocument xml;
    xml.LoadXml(L"<toast><visual><binding template='ToastGeneric'><text/><text/></binding></visual></toast>");
    auto nodes = xml.GetElementsByTagName(L"text");
    nodes.Item(0).AppendChild(xml.CreateTextNode(winrt::to_hstring(title)));
    nodes.Item(1).AppendChild(xml.CreateTextNode(winrt::to_hstring(text)));
    winrt::Windows::UI::Notifications::ToastNotification toast(xml);
    toast.Tag(winrt::hstring(std::to_wstring(chat).substr(0, 16)));
    toast.Group(L"messages");
    winrt::Windows::UI::Notifications::ToastNotificationManager::CreateToastNotifier().Show(toast);
    values.Insert(key, winrt::box_value(time));
}

struct BackgroundService : std::enable_shared_from_this<BackgroundService> {
    std::atomic<bool> foreground{false};
    std::atomic<uint64_t> epoch{0};
    std::mutex session_mutex;
    std::mutex worker_mutex;
    std::shared_ptr<Session> active;
    winrt::Windows::ApplicationModel::Background::ApplicationTrigger bootstrap{nullptr};
    winrt::guid socket_task{};

    static void Log(winrt::hstring const& text) {
        try { winrt::Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"backgroundStatus", winrt::box_value(text)); } catch (...) {}
    }
    winrt::Windows::Foundation::IAsyncAction Configure() {
        using namespace winrt::Windows::ApplicationModel::Background;
        if (!BackgroundEnabled()) co_return;
        auto access = co_await BackgroundExecutionManager::RequestAccessAsync();
        if (access == BackgroundAccessStatus::DeniedBySystemPolicy || access == BackgroundAccessStatus::DeniedByUser || access == BackgroundAccessStatus::Denied) { Log(L"Windows запретила фоновую работу. Разрешите Komet в параметрах батареи."); co_return; }
        for (auto const& entry : BackgroundTaskRegistration::AllTasks()) {
            auto name = entry.Value().Name();
            if (name == L"Komet.Socket") socket_task = entry.Key();
            if (name == L"Komet.Start") entry.Value().Unregister(true);
        }
        if (socket_task == winrt::guid{}) {
            BackgroundTaskBuilder builder;
            builder.Name(L"Komet.Socket");
            builder.IsNetworkRequested(true);
            builder.SetTrigger(SocketActivityTrigger());
            socket_task = builder.Register().TaskId();
        }
        bootstrap = ApplicationTrigger();
        BackgroundTaskBuilder builder;
        builder.Name(L"Komet.Start");
        builder.IsNetworkRequested(true);
        builder.SetTrigger(bootstrap);
        builder.Register();
        bool periodic = false;
        for (auto const& entry : BackgroundTaskRegistration::AllTasks()) if (entry.Value().Name() == L"Komet.Recover") periodic = true;
        if (!periodic) {
            BackgroundTaskBuilder fallback;
            fallback.Name(L"Komet.Recover");
            fallback.IsNetworkRequested(true);
            fallback.SetTrigger(TimeTrigger(15, false));
            fallback.AddCondition(SystemCondition(SystemConditionType::InternetAvailable));
            fallback.Register();
        }
        Log(L"Фоновые задачи зарегистрированы. Ожидается передача сокета при сворачивании.");
    }
    winrt::fire_and_forget Start() {
        auto self = shared_from_this();
        if (bootstrap && BackgroundEnabled()) { try { co_await bootstrap.RequestAsync(); } catch (winrt::hresult_error const& e) { Log(e.message()); } }
    }
    void Foreground() {
        foreground = true;
        ++epoch;
        std::lock_guard<std::mutex> lock(session_mutex);
        if (active) active->Close();
        active.reset();
        try {
            auto sockets = winrt::Windows::Networking::Sockets::SocketActivityInformation::AllSockets();
            if (sockets.HasKey(L"Komet.Background")) sockets.Lookup(L"Komet.Background").StreamSocket().Close();
        } catch (...) {}
    }
    winrt::fire_and_forget Run(winrt::Windows::ApplicationModel::Background::IBackgroundTaskInstance instance) {
        auto self = shared_from_this();
        auto deferral = instance.GetDeferral();
        auto cancelled = std::make_shared<std::atomic<bool>>(false);
        co_await winrt::resume_background();
        std::unique_lock<std::mutex> worker(worker_mutex, std::try_to_lock);
        if (!worker.owns_lock()) { deferral.Complete(); co_return; }
        auto cancel = instance.Canceled([self, cancelled](auto const&, auto const&) {
            *cancelled = true;
            std::lock_guard<std::mutex> lock(self->session_mutex);
            if (self->active) self->active->Close();
        });
        try {
            if (!worker.owns_lock() || foreground || !BackgroundEnabled()) throw std::runtime_error("Фоновый запуск пропущен.");
            auto expected = epoch.load();
            auto values = winrt::Windows::Storage::ApplicationData::Current().LocalSettings().Values();
            auto credential = winrt::Windows::Security::Credentials::PasswordVault().Retrieve(L"KometW10M", L"session");
            credential.RetrievePassword();
            auto token = winrt::to_string(credential.Password());
            auto device = winrt::to_string(winrt::unbox_value<winrt::hstring>(values.Lookup(L"deviceId")));
            auto me = values.HasKey(L"activeAccount") ? winrt::unbox_value<int64_t>(values.Lookup(L"activeAccount")) : 0;
            auto snapshot = std::make_shared<Json>();
            try { *snapshot = Cache::Read(); } catch (...) {}
            auto current = std::make_shared<Session>();
            current->OnPush([snapshot, me](Frame frame) {
                if (frame.opcode != 128) return;
                try { NotifyMessage(Object(frame.payload, "message"), Integer(frame.payload, "chatId"), me, *snapshot); } catch (...) {}
            });
            {
                std::lock_guard<std::mutex> lock(session_mutex);
                if (foreground || epoch != expected || *cancelled) throw std::runtime_error("Приложение вернулось на экран.");
                active = current;
            }
            auto details = instance.TriggerDetails().try_as<winrt::Windows::Networking::Sockets::SocketActivityTriggerDetails>();
            if (details && details.Reason() == winrt::Windows::Networking::Sockets::SocketActivityTriggerReason::SocketClosed) {
                try {
                    auto sockets = winrt::Windows::Networking::Sockets::SocketActivityInformation::AllSockets();
                    if (sockets.HasKey(L"Komet.Background")) sockets.Lookup(L"Komet.Background").StreamSocket().Close();
                } catch (...) {}
            }
            if (details && details.Reason() != winrt::Windows::Networking::Sockets::SocketActivityTriggerReason::SocketClosed) {
                auto info = details.SocketInformation();
                Bytes context;
                if (info.Context()) {
                    auto reader = winrt::Windows::Storage::Streams::DataReader::FromBuffer(info.Context().Data());
                    context.resize(reader.UnconsumedBufferLength()); reader.ReadBytes(context);
                }
                current->Adopt(info.StreamSocket(), context);
            } else {
                auto sockets = winrt::Windows::Networking::Sockets::SocketActivityInformation::AllSockets();
                if (sockets.HasKey(L"Komet.Background")) {
                    std::lock_guard<std::mutex> lock(session_mutex); active.reset();
                    throw std::runtime_error("Фоновый сокет уже передан Windows.");
                }
                winrt::guid task = socket_task;
                if (task == winrt::guid{}) for (auto const& entry : winrt::Windows::ApplicationModel::Background::BackgroundTaskRegistration::AllTasks()) if (entry.Value().Name() == L"Komet.Socket") task = entry.Key();
                if (task == winrt::guid{}) throw std::runtime_error("Фоновая задача сокета не зарегистрирована.");
                bool native = values.HasKey(L"nativeTransport") && winrt::unbox_value<bool>(values.Lookup(L"nativeTransport"));
                if (native) current->BrokerTask(task);
                current->Connect(device, native);
                auto login = current->Login(token, false);
                for (auto const& chat : Array(login, "chats")) NotifyMessage(Object(chat, "lastMessage"), Integer(chat, "id"), me, *snapshot);
            }
            current->Ping(false);
            for (int i = 0; i < 10 && !foreground && epoch == expected && !*cancelled; ++i) std::this_thread::sleep_for(std::chrono::milliseconds(100));
            {
                std::lock_guard<std::mutex> lock(session_mutex);
                if (foreground || epoch != expected || *cancelled) current->Close();
                else if (current->IsNative()) { current->Transfer(L"Komet.Background"); Log(L"Сокет передан системному брокеру. Уведомления включены."); }
                else { current->Close(); Log(L"Для веб-сессии включена периодическая проверка сообщений. Socket broker доступен для входа по коду."); }
                if (active == current) active.reset();
            }
        } catch (winrt::hresult_error const& e) { Log(L"Фон: " + e.message() + L" (" + winrt::to_hstring(int32_t(e.code())) + L")"); }
        catch (std::exception const& e) { Log(winrt::to_hstring(e.what())); }
        if (worker.owns_lock()) {
            std::lock_guard<std::mutex> lock(session_mutex);
            if (active) active->Close();
            active.reset();
        }
        instance.Canceled(cancel);
        deferral.Complete();
    }
};
}
