/**
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>. 
**/


namespace RocketLauncher {
    public class ApplicationHandler : GLib.Object {
        private string[] directories;
        private string[] directories_fallback = {
            "/usr/share/applications",
            "/usr/local/share/applications",
            GLib.Environment.get_home_dir()+"/.local/share/applications"
        };
        
        private App[] apps;
        private int[] apps_selected;
        
        public ApplicationHandler() {
            // Setup the environment
            setup_environment();
            
            //Scan applications
            apps = scan_applications();
            
            // Set filter to all
            //filter_all();
        }
        
        private void setup_environment() {
            //Select right directories to search in
            
            //If XDG_DATA_DIRS is set use all listed directories+/applications
            //to search for desktop files. Also search in some default locations
            //If XDG_DATA_DIRS is not set only search in default locations
            //Notice: It is not checked whether these directories exist, but
            //it should not be a problem if they don't. 
            string directories_environ = GLib.Environment.get_variable("XDG_DATA_DIRS");
            
            if (directories_environ != null) {
                List<string> directories_l = new List<string>();
                
                //Append values from $XDG_DATA_DIRS
                foreach (string dir in directories_environ.split(":")) {
                    //Append '/' if necessary
                    //then append "applications"
                    if (dir.to_utf8()[dir.length-1] != '/') {
                        dir = string.join("", dir, "/applications");
                    } else {
                        dir = string.join("", dir, "applications");
                    }
                    /* XDG_DATA_DIRS could contains duplicate, we must add a dir only one time */
                    if (directories_l.find_custom(dir,strcmp) == null)
                        directories_l.append(dir);
                }
                
                //Append fallback values if they aren't already in list
                foreach (string fallback_dir in directories_fallback) {
                    if (directories_l.find_custom(fallback_dir, strcmp) == null)
                        directories_l.append(fallback_dir);
                }
                
                //Convert List to array
                directories = new string[directories_l.length()];
                for (int i = 0; i < directories_l.length(); i++) {
                    directories[i] = directories_l.nth_data(i);
                }
            } else {
                string warn_str = "";
                warn_str += "Error occured while scanning for directories,\n";
                warn_str += "that contain .desktop files.\n";
                warn_str += "Environment variable $XDG_DATA_DIRS is not set!\n";
                warn_str += "Ignoring directory $XDG_DATA_DIRS/applications ...\n";
                warn_str += "Using fallback directories ...\n";
                for (int i = 0; i < directories_fallback.length; i++) {
                    warn_str += "Fallback: ";
                    warn_str += directories_fallback[i];
                    warn_str += "\n";
                }
                print_warning(warn_str);
                
                directories = directories_fallback;
            }
        }
        
        private App[] scan_applications() {
	        IconManager icon_manager = new IconManager();
            // Go through all directories containing .desktop files
            // and create a list of (absolute) paths to .desktop files.
            GLib.List<string> desktop_file_list = new GLib.List<string>();
            
            foreach (string d in directories) {
                GLib.File directory = GLib.File.new_for_path(d);
                
                // If the directory does not exist we simly skip it.
                if (directory.query_exists() == false) {
                    continue;
                }
                
                try {
                    // Go through all files in this directory
                    GLib.FileEnumerator enm = directory.enumerate_children(
                                FileAttribute.STANDARD_NAME,
                                GLib.FileQueryInfoFlags.NONE);
                    GLib.FileInfo fileInfo;
                    while((fileInfo = enm.next_file()) != null) {
                        
                        // If the file has the right suffix we'll add
                        // it to the list.
                        string x = d+"/"+fileInfo.get_name();
                        if (x.has_suffix(".desktop")) {
                            desktop_file_list.append(x);
                        }
                    }
                }
                catch (Error e) {
                    string error_str = "Error occured while looking for .desktop files in directory\n";
                    error_str += "Error: \""+e.message+"\"\n";
                    error_str += "Directory: \""+d+"\"\n";
                    error_str += "Ignoring directory and possibly all desktop files in it ...";
                    
                    print_warning(error_str);
                }
            }
            
            // We create an Object from every .desktop file in our list
            // and put this object in a list (which we return).
            
            //TODO: Multi-thread
            
            List<App> apps = new List<App>();             
            foreach (string desktop_file in desktop_file_list) {
                App app = new App(desktop_file, icon_manager);
                    
                if (app.is_valid()) {
                    apps.insert_sorted(app, (a1, a2) => strcmp(a1.get_name().down(), a2.get_name().down() ));
                }
            }
            
            // Convert to array
            App[] apps_ar = new App[apps.length()];
            for (int i = 0; i < apps.length(); i++) {
                apps_ar[i] = apps.nth_data(i);
            }
            return apps_ar;
        }
        
        public App[] get_apps() {
            return apps;
        }
        
        public int[] get_selected_apps() {
            return apps_selected;
        }
        
        public signal void selection_changed();
        
        public void filter_all() {
            int[] all = new int[apps.length];
            
            for (int i = 0; i < apps.length; i++) {
                all[i] = i;
            }
            
            this.apps_selected = all;
            selection_changed();
        }
        
        public void filter_categorie(string? filter) {
            if (filter == null || filter == "") {
                filter_all();
                return;
            }
            
            List<int> filtered_list = new List<int>();
            
            for (int i = 0; i < apps.length; i++) {
                App app = apps[i];
                string[] categories = app.get_categories();
                
                for (int p = 0; p < categories.length; p++) {
                    if (filter == categories[p]) {
                        filtered_list.append(i);
                        break;
                    }
                }
            }
            
            
            // Convert list to array
            int[] filtered_ar = new int[filtered_list.length()];
            for (int i = 0; i < filtered_list.length(); i++) {
                filtered_ar[i] = filtered_list.nth_data(i);
            }
            
            // Set value and send signal
            this.apps_selected = filtered_ar;
            selection_changed();
        }
        
        public void filter_string(string? filter) {
            if (filter == null || filter == "") {
                filter_all();
                return;
            }
            
            List<int> filtered_list = new List<int>();
            
            for (int i = 0; i < apps.length; i++) {
                App app = apps[i];
                
                // Check for matching name
                if (app.get_name().down().contains(filter.down())) {
                    filtered_list.append(i);
                    continue;
                }
                
                // Check for matching generic name
                string gen = app.get_generic();
                if (gen != null) {
                    if (gen.down().contains(filter.down())) {
                        filtered_list.append(i);
                        continue;
                    }
                }
                
                // Check for matching category
                string[] categories = app.get_categories();
                if (categories != null) {
                    for (int p = 0; p < categories.length; p++) {
                        if (categories[p].down().contains(filter.down())) {
                            filtered_list.append(i);
                            break;
                        }
                    }
                }
            }
            
            // Convert list to array
            int[] filtered_ar = new int[filtered_list.length()];
            for (int i = 0; i < filtered_list.length(); i++) {
                filtered_ar[i] = filtered_list.nth_data(i);
            }
            
            // Set value and send signal
            this.apps_selected = filtered_ar;
            selection_changed();
        }
    }
}
