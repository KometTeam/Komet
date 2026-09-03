#include "clipboard_media_channel.h"

#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gtk/gtk.h>

#include <cstring>

static constexpr char kChannelName[] = "ru.komet.app/clipboard";

static GtkClipboard* system_clipboard() {
  return gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
}

static gboolean clipboard_has_image() {
  GtkClipboard* board = system_clipboard();
  return gtk_clipboard_wait_is_image_available(board) &&
         !gtk_clipboard_wait_is_text_available(board);
}

static gboolean clipboard_has_media() {
  return gtk_clipboard_wait_is_uris_available(system_clipboard()) ||
         clipboard_has_image();
}

static FlValue* read_files() {
  GtkClipboard* board = system_clipboard();
  if (!gtk_clipboard_wait_is_uris_available(board)) {
    return nullptr;
  }

  g_auto(GStrv) uris = gtk_clipboard_wait_for_uris(board);
  if (uris == nullptr) {
    return nullptr;
  }

  g_autoptr(FlValue) files = fl_value_new_list();
  for (gchar** uri = uris; *uri != nullptr; uri++) {
    g_autofree gchar* path = g_filename_from_uri(*uri, nullptr, nullptr);
    if (path == nullptr) {
      continue;
    }
    fl_value_append_take(files, fl_value_new_string(path));
  }
  if (fl_value_get_length(files) == 0) {
    return nullptr;
  }

  FlValue* result = fl_value_new_map();
  fl_value_set_string(result, "files", files);
  return result;
}

static FlValue* read_image() {
  if (!clipboard_has_image()) {
    return nullptr;
  }

  g_autoptr(GdkPixbuf) pixbuf =
      gtk_clipboard_wait_for_image(system_clipboard());
  if (pixbuf == nullptr) {
    return nullptr;
  }

  gchar* raw = nullptr;
  gsize size = 0;
  g_autoptr(GError) error = nullptr;
  if (!gdk_pixbuf_save_to_buffer(pixbuf, &raw, &size, "png", &error, nullptr)) {
    g_warning("Failed to encode the pasted image: %s",
              error == nullptr ? "unknown error" : error->message);
    return nullptr;
  }

  g_autofree gchar* png = raw;
  if (size == 0) {
    return nullptr;
  }

  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(
      result, "image",
      fl_value_new_uint8_list(reinterpret_cast<const uint8_t*>(png), size));
  fl_value_set_string_take(result, "imageExtension", fl_value_new_string(".png"));
  return result;
}

static FlValue* read_media() {
  FlValue* files = read_files();
  if (files != nullptr) {
    return files;
  }
  return read_image();
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "hasMedia") == 0) {
    g_autoptr(FlValue) value = fl_value_new_bool(clipboard_has_media());
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  } else if (strcmp(method, "read") == 0) {
    g_autoptr(FlValue) value = read_media();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to answer a clipboard call: %s", error->message);
  }
}

void clipboard_media_channel_register(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry,
                                                  "ClipboardMediaChannel");
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr,
                                            nullptr);
}
