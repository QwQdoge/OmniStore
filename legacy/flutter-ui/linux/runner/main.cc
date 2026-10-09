#include "my_application.h"

int main(int argc, char** argv) {
  // KDE mixed-DPI sessions can export GDK_BACKEND=x11 globally. Running the
  // Flutter GTK shell through XWayland then applies the largest monitor scale
  // to every window (for example, a 1440px window appears only ~823px wide at
  // 1.75x). Prefer native Wayland for per-output fractional scaling while
  // retaining X11 as an explicit fallback if the compositor is unavailable.
  const gchar* session_type = g_getenv("XDG_SESSION_TYPE");
  const gchar* configured_backend = g_getenv("GDK_BACKEND");
  if (g_strcmp0(session_type, "wayland") == 0 &&
      g_strcmp0(configured_backend, "x11") == 0) {
    g_setenv("GDK_BACKEND", "wayland,x11", TRUE);
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
