#ifndef FLUTTER_MY_APPLICATION_H_
#define FLUTTER_MY_APPLICATION_H_

#if defined(__linux__) || (defined(__has_include) && __has_include(<gtk/gtk.h>))
#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(MyApplication,
                     my_application,
                     MY,
                     APPLICATION,
                     GtkApplication)
#else
// Fallback declarations for IDE language servers when opened on non-Linux hosts (e.g. Windows)
typedef struct _GtkWidget GtkWidget;
typedef struct _GtkWindow GtkWindow;
typedef struct _GtkHeaderBar GtkHeaderBar;
struct _GtkApplication { int _unused; };
typedef struct _GtkApplication GtkApplication;
typedef struct _GApplication GApplication;
typedef struct _GObject GObject;
struct _GError { const char* message; };
typedef struct _GError GError;
typedef struct _GdkScreen GdkScreen;
typedef struct _FlView FlView;
typedef struct _FlDartProject FlDartProject;
typedef struct _FlPluginRegistry FlPluginRegistry;
typedef int gboolean;
typedef char gchar;
typedef void* gpointer;
typedef struct { double red, green, blue, alpha; } GdkRGBA;

#define TRUE 1
#define FALSE 0
#define GTK_TYPE_APPLICATION 0
#define G_APPLICATION_NON_UNIQUE 0

#ifndef APPLICATION_ID
#define APPLICATION_ID "com.chatgen.whisper"
#endif

typedef struct _MyApplication MyApplication;

struct _GApplicationClass {
  void (*activate)(GApplication*);
  gboolean (*local_command_line)(GApplication*, gchar***, int*);
  void (*startup)(GApplication*);
  void (*shutdown)(GApplication*);
};
typedef struct _GApplicationClass GApplicationClass;

struct _GObjectClass {
  void (*dispose)(GObject*);
};
typedef struct _GObjectClass GObjectClass;

typedef struct {
  GApplicationClass parent_class;
} MyApplicationClass;

#define G_DEFINE_TYPE(TN, t_n, T_P)
#define MY_APPLICATION(obj) ((MyApplication*)(obj))
#define GTK_WINDOW(obj) ((GtkWindow*)(obj))
#define GTK_APPLICATION(obj) ((GtkApplication*)(obj))
#define GTK_HEADER_BAR(obj) ((GtkHeaderBar*)(obj))
#define GTK_WIDGET(obj) ((GtkWidget*)(obj))
#define GTK_CONTAINER(obj) (obj)
#define G_APPLICATION_CLASS(klass) ((GApplicationClass*)(klass))
#define G_OBJECT_CLASS(klass) ((GObjectClass*)(klass))
#define G_CALLBACK(f) ((void*)(f))
#define FL_PLUGIN_REGISTRY(v) ((FlPluginRegistry*)(v))
#define g_autoptr(Type) Type*
#define GDK_IS_X11_SCREEN(screen) 0
#endif

/**
 * my_application_new:
 *
 * Creates a new Flutter-based application.
 *
 * Returns: a new #MyApplication.
 */
MyApplication* my_application_new();

#endif  // FLUTTER_MY_APPLICATION_H_
