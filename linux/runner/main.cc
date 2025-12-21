#include "my_application.h"
#include <glib.h>
#include <gdk/gdk.h>

int main(int argc, char** argv) {
  g_setenv("GDK_SYNCHRONIZE", "0", TRUE);
  g_setenv("G_MESSAGES_DEBUG", "", TRUE);
  g_setenv("GTK_DEBUG", "no-css-cache", TRUE);

  gdk_set_allowed_backends("x11");
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
