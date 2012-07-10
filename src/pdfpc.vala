/**
 * Main application file
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

using Gtk;

namespace pdfpc {
    /**
     * Pdf Presenter Console main application class
     *
     * This class contains the main method as well as all the logic needed for
     * initializing the application, like commandline parsing and window creation.
     */
    public class Application: GLib.Object {

		/**
		 * This string contains the path where the UI is stored
		 */

		string basepath;

        /**
         * Window which shows the current slide in fullscreen
         *
         * This window is supposed to be shown on the beamer
         */
        private Window.Presentation presentation_window;

        /**
         * Presenter window showing the current and the next slide as well as
         * different other meta information useful for the person giving the
         * presentation.
         */
        private Window.Presenter presenter_window;

        /**
         * PresentationController instanace managing all actions which need to
         * be coordinated between the different windows
         */
        private PresentationController controller;

        /**
         * CacheStatus widget, which coordinates all the information about
         * cached slides to provide a visual feedback to the user about the
         * rendering state
         */
        private CacheStatus cache_status;

		/**
		 * Interface elements
		 */

		private Gtk.Window main_w;
		private Gtk.Button ui_go;
		private Gtk.Button ui_exit;
		private Gtk.Button ui_about;
		private Gtk.CheckButton ui_sw_scr;
		private Gtk.CheckButton ui_add_black_slide;
		private Gtk.SpinButton ui_duration;
		private Gtk.SpinButton ui_alert;
		private Gtk.SpinButton ui_size;
		private Gtk.FileChooserButton ui_file;

        /**
         * Commandline option parser entry definitions
         */
        const OptionEntry[] options = {
            { "duration", 'd', 0, OptionArg.INT, ref Options.duration, "Duration in minutes of the presentation used for timer display.", "N" },
            { "end-time", 'e', 0, OptionArg.STRING, ref Options.end_time, "End time of the presentation. (Format: HH:MM (24h))", "T" },
            { "last-minutes", 'l', 0, OptionArg.INT, ref Options.last_minutes, "Time in minutes, from which on the timer changes its color. (Default 5 minutes)", "N" },
            { "start-time", 't', 0, OptionArg.STRING, ref Options.start_time, "Start time of the presentation to be used as a countdown. (Format: HH:MM (24h))", "T" },
            { "current-size", 'u', 0, OptionArg.INT, ref Options.current_size, "Percentage of the presenter screen to be used for the current slide. (Default 60)", "N" },
            { "overview-min-size", 'o', 0, OptionArg.INT, ref Options.min_overview_width, "Minimum width for the overview miniatures, in pixels. (Default 150)", "N" },
            { "switch-screens", 's', 0, 0, ref Options.display_switch, "Switch the presentation and the presenter screen.", null },
			{ "no-switch-screens", 'n', 0, 0, ref Options.display_unswitch, "Unswitch the presentation and the presenter screen. It disables a previous -s parameter.", null },
            { "disable-cache", 'c', 0, 0, ref Options.disable_caching, "Disable caching and pre-rendering of slides to save memory at the cost of speed.", null },
            { "disable-compression", 'z', 0, 0, ref Options.disable_cache_compression, "Disable the compression of slide images to trade memory consumption for speed. (Avg. factor 30)", null },
            { "black-on-end", 'b', 0, 0, ref Options.black_on_end, "Add an additional black slide at the end of the presentation", null },
            { "single-screen", 'S', 0, 0, ref Options.single_screen, "Force to use only one screen", null },
            { "list-actions", 'L', 0, 0, ref Options.list_actions, "List actions supported in the config file(s)", null},
            { "windowed", 'w', 0, 0, ref Options.windowed, "Run in windowed mode (devel tool)", null},
			{ "run-now", 'r', 0, 0, ref Options.run_now, "Launch the presentation directly, without showing the user interface", null},
            { null }
        };

        /**
         * Parse the commandline and apply all found options to there according
         * static class members.
         *
		 * Returns the name of the pdf file to open (or null if not present)
         */
        protected string? parse_command_line_options( string[] args ) {
            var context = new OptionContext( "<pdf-file>" );

            context.add_main_entries( options, null );
            
            try {
                context.parse( ref args );
            }
            catch( OptionError e ) {
                stderr.printf( "\n%s\n\n", e.message );
                stderr.printf( "%s", context.get_help( true, null ) );
                Posix.exit( 1 );
            }
            if ( args.length < 2 ) {
				return null;
            } else {
				return args[1];
			}
        }

        /**
         * Create and return a PresenterWindow using the specified monitor
         * while displaying the given file
         */
        private Window.Presenter create_presenter_window( Metadata.Pdf metadata, int monitor ) {
            var presenter_window = new Window.Presenter( metadata, monitor, this.controller );
            //controller.register_controllable( presenter_window );
            presenter_window.set_cache_observer( this.cache_status );

            return presenter_window;
        }

        /**
         * Create and return a PresentationWindow using the specified monitor
         * while displaying the given file
         */
        private Window.Presentation create_presentation_window( Metadata.Pdf metadata, int monitor ) {
            var presentation_window = new Window.Presentation( metadata, monitor, this.controller );
            //controller.register_controllable( presentation_window );
            presentation_window.set_cache_observer( this.cache_status );

            return presentation_window;
        }

		/**
		 * This callback kills the current presentation and shows the main window
		 */

		public void kill_presentation() {

			this.controller.signal_close_presentation.disconnect(this.kill_presentation);
			if (this.presentation_window!=null) {
				this.presentation_window.destroy();
				this.presentation_window=null;
			}
			if (this.presenter_window!=null) {
				this.presenter_window.destroy();
				this.presenter_window=null;
			}
			// controller and cache status should have a destructor method, to ensure
			// that all the memory is freed here (I'm not sure, but seems to be a little
			// memory leak when launching a presentation over and over again)
			this.controller=null;
			this.cache_status=null;

			if (Options.run_now) {
				// If we are running the presentation directly, now we have to exit
				Gtk.main_quit();
			} else {
				// If not, we have to show the main window
				this.main_w.show();
			}
		}


		/**
		 * This callback starts a presentation from the main window
		 */
		
		public void start_presentation() {

			this.main_w.hide();

			// Update internal options acording to the ones in the GUI
			Options.display_switch=this.ui_sw_scr.active;
			Options.black_on_end=this.ui_add_black_slide.active;
			Options.duration=this.ui_duration.get_value_as_int();
			Options.last_minutes=this.ui_alert.get_value_as_int();
			Options.current_size=this.ui_size.get_value_as_int();

			// Remember the last used options
			this.write_configuration();

			// And launch the presentation
			this.do_slide (this.ui_file.get_file().get_uri());
			
		}
		
        /**
         * Main application function, which instantiates the windows and
         * initializes the Gtk system.
         */
        public void do_slide( string pdfFilename ) {
			
			if (pdfFilename == null) {
				stderr.printf( "Error: No pdf file given\n");
				Posix.exit(1);
			}

            stdout.printf( "Initializing rendering...\n" );

            var metadata = new Metadata.Pdf( pdfFilename );
            if ( Options.duration != 987654321u )
                metadata.set_duration(Options.duration);

            // Initialize global controller and CacheStatus, to manage
            // crosscutting concerns between the different windows.
            this.controller = new PresentationController( metadata, Options.black_on_end );
            this.cache_status = new CacheStatus();
			this.controller.signal_close_presentation.connect(this.kill_presentation);

            ConfigFileReader configFileReader = new ConfigFileReader(this.controller);
            configFileReader.readConfig(GLib.Path.build_filename(etc_path, "pdfpcrc"));
            configFileReader.readConfig(GLib.Path.build_filename(Environment.get_home_dir(),".pdfpcrc"));
            configFileReader.readConfig(GLib.Path.build_filename(Environment.get_home_dir(),".config","pdfpc","pdfpcrc"));

            var screen = Gdk.Screen.get_default();
            if ( !Options.windowed && !Options.single_screen && screen.get_n_monitors() > 1 ) {
                int presenter_monitor, presentation_monitor;
                if ( Options.display_switch != true )
                    presenter_monitor    = screen.get_primary_monitor();
                else
                    presenter_monitor    = (screen.get_primary_monitor() + 1) % 2;
                presentation_monitor = (presenter_monitor + 1) % 2;
                this.presentation_window = 
                    this.create_presentation_window( metadata, presentation_monitor );
                this.presenter_window = 
                    this.create_presenter_window( metadata, presenter_monitor );
            } else if (Options.windowed && !Options.single_screen) {
                this.presenter_window =
                    this.create_presenter_window( metadata, -1 );
                this.presentation_window =
                    this.create_presentation_window( metadata, -1 );
            } else {
                    if ( !Options.display_switch)
                        this.presenter_window =
                            this.create_presenter_window( metadata, -1 );
                    else
                        this.presentation_window =
                            this.create_presentation_window( metadata, -1 );
            }

            // The windows are always displayed at last to be sure all caches have
            // been created at this point.
            if ( this.presentation_window != null ) {
                this.presentation_window.show_all();
                this.presentation_window.update();
            }
            
            if ( this.presenter_window != null ) {
                this.presenter_window.show_all();
                this.presenter_window.update();
            }
        }

		public void refresh_status() {

			var fname = this.ui_file.get_file();
			if (fname!=null) {
				var uri = fname.get_uri();
				if (uri==null) {
					this.ui_go.sensitive=false;
				} else {
					this.ui_go.sensitive=true;
				}
			}else {
				this.ui_go.sensitive=false;
			}
		}

		private int read_configuration() {
			
			/****************************************************************************************
			 * This function will read the configuration from the file ~/.pdf_presenter.cfg         *
			 * If not, it will use that file to get the configuration                               *
			 * Returns:                                                                             *
			 *   0: on success                                                                      *
			 *  -1: the config file doesn't exists                                                  *
			 *  -2: can't read the config file                                                      *
			 *  +N: parse error at line N in config file                                            *			 
			 ****************************************************************************************/

			bool failed=false;
			FileInputStream file_read;
			
			string home=Environment.get_home_dir();
			var config_file = File.new_for_path (GLib.Path.build_filename(home,".config","pdfpd","pdfpc.cfg"));
			
			if (!config_file.query_exists(null)) {
				return -1;
			}

			try {
				file_read=config_file.read(null);
			} catch {
				return -2;
			}
			var in_stream = new DataInputStream (file_read);
			string line;
			int line_counter=0;

			while ((line = in_stream.read_line (null, null)) != null) {
				line_counter++;
				
				// ignore comments
				if (line[0]=='#') {
					continue;
				}
				
				// remove unwanted blank spaces
				line.strip();

				// ignore empty lines				
				if (line.length==0) {
					continue;
				}
				
				if (line.has_prefix("switch_screens ")) {
					if (line.substring(15)=="1") {
						Options.display_switch=true;
					} else {
						Options.display_switch=false;
					}
					continue;
				}
				if (line.has_prefix("duration ")) { // old option. Don't use it any more
					continue;
				}
				if (line.has_prefix("last_minutes ")) {
					Options.last_minutes=int.parse(line.substring(13).strip());
					continue;
				}
				if (line.has_prefix("current_size ")) {
					Options.current_size=int.parse(line.substring(13).strip());
					continue;
				}
				failed=true;
				break;
			}

			try {
				in_stream.close(null);
			} catch {
			}
			try {
				file_read.close(null);
			} catch {
			}

			if (failed) {
				GLib.stderr.printf(_("Invalid parameter in config file %s (line %d)\n"),config_file.get_path(),line_counter);
				return line_counter;
			}
			
			return 0;
		}

		public int write_configuration() {

			try {
				FileOutputStream file_write;
		
				var home=Environment.get_home_dir();

				var cfg_path=GLib.Path.build_filename(home,".config","pdfpc");
				GLib.DirUtils.create_with_parents(cfg_path,493); // 493 = 755 in octal (for directory permissions)
				var config_file = File.new_for_path (GLib.Path.build_filename(cfg_path,"pdfpc.cfg"));
		
				try {
					file_write=config_file.replace(null,false,0,null);
				} catch {
					return -2;
				}
		
				var out_stream = new DataOutputStream (file_write);
			
				if (Options.display_switch) {
					out_stream.put_string("switch_screens 1\n",null);
				} else {
					out_stream.put_string("switch_screens 0\n",null);
				}
				out_stream.put_string("last_minutes %u\n".printf(Options.last_minutes));
				out_stream.put_string("current_size %u\n".printf(Options.current_size));
				
			} catch (IOError e) {
			}		
			return 0;
		}

		
        /**
         * Main application function, which instantiates the windows and
         * initializes the Gtk system.
         */
        public void run( string[] args ) {

            stdout.printf( "pdfpc v3.1.1\n"
                           + "(C) 2012 David Vilar\n"
                           + "(C) 2009-2011 Jakob Westhoff\n\n" );

            Gdk.threads_init();
            Gtk.init( ref args );

			// First, read the configuration with the last options used (to remember if we
			// have to switch screens and so on)
			this.read_configuration ();

			// Now, read the command line options, overwriting the ones set by the
			// READ_CONFIGURATION function
            string pdfFilename = this.parse_command_line_options( args );
            if (Options.list_actions) {
				stdout.printf("Config file commands accepted by pdfpc:\n");
				string[] actions = PresentationController.getActionDescriptions();
				for (int i = 0; i < actions.length; i+=2) {
					string tabAlignment = "\t";
					if (actions[i].length < 8)
						tabAlignment += "\t";
					stdout.printf("\t%s%s=> %s\n", actions[i], tabAlignment, actions[i+1]);
				}
                return;
            }

			// This option is needed because the previously stored configuration could mandate
			// to switch the screens, but now the user doesn't want to do it from command line
			if (Options.display_unswitch) {
				Options.display_switch=false;
			}
			
			// Find where the GUI definition files are (/usr or /usr/local) and set locale
			var file=File.new_for_path("/usr/share/pdfpc/main.ui");
			if (file.query_exists()) {
				this.basepath="/usr/share/pdfpc/";
				Intl.bindtextdomain( "pdfpc", "/usr/share/locale");
			} else {
				this.basepath="/usr/local/share/pdfpc/";
				Intl.bindtextdomain( "pdfpc", "/usr/local/share/locale");
			}
			Intl.textdomain("pdfpc");
			Intl.bind_textdomain_codeset( "pdfpc", "UTF-8" );

            // Initialize the application wide mutex objects
            MutexLocks.init();

			var builder = new Builder();
			builder.add_from_file(GLib.Path.build_filename(this.basepath,"main.ui"));
			this.main_w = (Gtk.Window)builder.get_object("main_window");

			var builder2 = new Builder();		
			builder2.add_from_file(GLib.Path.build_filename(this.basepath,"about.ui"));
			var about_w = (Gtk.Dialog)builder2.get_object("aboutdialog");

			// Get access to all the important widgets in the GUI 
			this.ui_go = (Gtk.Button)builder.get_object("button_go");
			this.ui_exit = (Gtk.Button)builder.get_object("button_exit");
			this.ui_about = (Gtk.Button)builder.get_object("button_about");
			this.ui_sw_scr = (Gtk.CheckButton)builder.get_object("switch_screens");
			this.ui_add_black_slide = (Gtk.CheckButton)builder.get_object("add_black_slide");
			this.ui_duration = (Gtk.SpinButton)builder.get_object("duration_time");
			this.ui_alert = (Gtk.SpinButton)builder.get_object("alert_time");
			this.ui_size = (Gtk.SpinButton)builder.get_object("size_slide");
			this.ui_file = (Gtk.FileChooserButton)builder.get_object("pdf_file");
			this.ui_file.file_set.connect(this.refresh_status);
			this.ui_file.selection_changed.connect(this.refresh_status);
			this.ui_go.clicked.connect(this.start_presentation);
			this.main_w.destroy.connect( (source) => {
				Gtk.main_quit();
            } );
			this.ui_exit.clicked.connect( (source) => {
				Gtk.main_quit();
            } );
			this.ui_about.clicked.connect( (source) => {
				this.main_w.hide();
				about_w.show();
				about_w.run();
				about_w.hide();
				this.main_w.show();
            } );
			
			if (pdfFilename!=null) {
				var fname = File.new_for_path(pdfFilename);
				this.ui_file.set_file(fname);
			}
			
			Gdk.threads_enter();

			if (Options.run_now) {
				// If the user set the -r option, launch the presentation just now
				this.do_slide (pdfFilename);
			} else {
				// Set the GUI options acording to the ones currently active
				this.ui_sw_scr.active=Options.display_switch;
				this.ui_add_black_slide.active=Options.black_on_end;
				this.ui_duration.value=Options.duration;
				this.ui_alert.value=Options.last_minutes;
				this.ui_size.value=Options.current_size;
					
				main_w.show();
				this.refresh_status();
			}

			// Enter the Glib eventloop
            // Everything from this point on is completely signal based
			Gtk.main();
			Gdk.threads_leave();
        }

        /**
         * Basic application entry point
         */
        public static int main ( string[] args ) {
            var application = new Application();
            application.run( args );

            return 0;
        }
    }
}
