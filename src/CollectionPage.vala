/* Copyright 2009-2013 Yorba Foundation
 *
 * This software is licensed under the GNU LGPL (version 2.1 or later).
 * See the COPYING file in this distribution.
 */

public class CollectionViewManager : ViewManager {
    private CollectionPage page;

    public CollectionViewManager (CollectionPage page) {
        this.page = page;
    }

    public override DataView create_view (DataSource source) {
        return page.create_thumbnail (source);
    }
}

public abstract class CollectionPage : MediaPage {
    private const double DESKTOP_SLIDESHOW_TRANSITION_SEC = 2.0;

    protected class CollectionSearchViewFilter : DefaultSearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT | SearchFilterCriteria.FLAG |
                   SearchFilterCriteria.MEDIA | SearchFilterCriteria.RATING;
        }
    }

    private ExporterUI exporter = null;
    private CollectionSearchViewFilter search_filter = new CollectionSearchViewFilter ();
    private Gtk.ToggleToolButton enhance_button = null;
    public CollectionPage (string page_name) {
        base (page_name);

        get_view ().items_altered.connect (on_photos_altered);

        init_item_context_menu ("/CollectionContextMenu");
        init_toolbar ("/CollectionToolbar");

        show_all ();
    }

    public override Gtk.Toolbar get_toolbar () {
        if (toolbar == null) {
            base.get_toolbar ();
            // enhance tool
            enhance_button = new Gtk.ToggleToolButton.from_stock (Resources.ENHANCE);
            enhance_button.set_label (Resources.ENHANCE_LABEL);
            enhance_button.set_tooltip_text (Resources.ENHANCE_TOOLTIP);
            enhance_button.clicked.connect (on_enhance);
            enhance_button.is_important = true;
            toolbar.insert (enhance_button, 2);

            // separator to force slider to right side of toolbar
            Gtk.SeparatorToolItem separator = new Gtk.SeparatorToolItem ();
            separator.set_expand (true);
            separator.set_draw (false);
            get_toolbar ().insert (separator, -1);

            Gtk.SeparatorToolItem drawn_separator = new Gtk.SeparatorToolItem ();
            drawn_separator.set_expand (false);
            drawn_separator.set_draw (true);

            get_toolbar ().insert (drawn_separator, -1);

            // zoom slider assembly
            MediaPage.ZoomSliderAssembly zoom_slider_assembly = create_zoom_slider_assembly ();
            connect_slider (zoom_slider_assembly);
            get_toolbar ().insert (zoom_slider_assembly, -1);

            Gtk.Image start_image = new Gtk.Image.from_icon_name ("media-playback-start", Gtk.IconSize.LARGE_TOOLBAR);
            Gtk.ToolButton slideshow_button = new Gtk.ToolButton (start_image, _("S_lideshow"));
            slideshow_button.set_tooltip_text (_("Play a slideshow"));
            slideshow_button.clicked.connect (on_slideshow);
            get_toolbar ().insert (slideshow_button, 0);

            //  show metadata sidebar button
            show_sidebar_button = MediaPage.create_sidebar_button ();
            show_sidebar_button.clicked.connect (on_show_sidebar);
            toolbar.insert (show_sidebar_button, -1);
            var app = AppWindow.get_instance () as LibraryWindow;
            update_sidebar_action (!app.is_metadata_sidebar_visible ());
        }

        return toolbar;
    }

    private static InjectionGroup create_file_menu_injectables () {
        InjectionGroup group = new InjectionGroup ("/MenuBar/FileMenu/FileExtrasPlaceholder");

        return group;
    }

    private static InjectionGroup create_context_menu_injectables () {
        InjectionGroup group = new InjectionGroup ("/CollectionContextMenu/EditExtrasPlaceholder");

        group.add_menu_item ("Duplicate");

        return group;
    }

    private static InjectionGroup create_view_menu_fullscreen_injectables () {
        InjectionGroup group = new InjectionGroup ("/MediaViewMenu/ViewExtrasFullscreenSlideshowPlaceholder");

        group.add_menu_item ("Fullscreen", "CommonFullscreen");

        return group;
    }

    protected override void init_collect_ui_filenames (Gee.List<string> ui_filenames) {
        base.init_collect_ui_filenames (ui_filenames);

        ui_filenames.add ("collection.ui");
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry print = { "Print", Gtk.Stock.PRINT, TRANSLATABLE, "<Ctrl>P",
                                  TRANSLATABLE, on_print
                                };
        print.label = Resources.PRINT_MENU;
        actions += print;

        Gtk.ActionEntry publish = { "Publish", Resources.PUBLISH, TRANSLATABLE, "<Ctrl><Shift>P",
                                    TRANSLATABLE, on_publish
                                  };
        publish.label = Resources.PUBLISH_MENU;
        publish.tooltip = Resources.PUBLISH_TOOLTIP;
        actions += publish;

        Gtk.ActionEntry rotate_right = { "RotateClockwise", Resources.CLOCKWISE,
                                         TRANSLATABLE, "<Ctrl>R", TRANSLATABLE, on_rotate_clockwise
                                       };
        rotate_right.label = Resources.ROTATE_CW_MENU;
        rotate_right.tooltip = Resources.ROTATE_CW_TOOLTIP;
        actions += rotate_right;

        Gtk.ActionEntry rotate_left = { "RotateCounterclockwise", Resources.COUNTERCLOCKWISE,
                                        TRANSLATABLE, "<Ctrl><Shift>R", TRANSLATABLE, on_rotate_counterclockwise
                                      };
        rotate_left.label = Resources.ROTATE_CCW_MENU;
        rotate_left.tooltip = Resources.ROTATE_CCW_TOOLTIP;
        actions += rotate_left;

        Gtk.ActionEntry hflip = { "FlipHorizontally", Resources.HFLIP, TRANSLATABLE, null,
                                  TRANSLATABLE, on_flip_horizontally
                                };
        hflip.label = Resources.HFLIP_MENU;
        hflip.tooltip = Resources.HFLIP_TOOLTIP;
        actions += hflip;

        Gtk.ActionEntry vflip = { "FlipVertically", Resources.VFLIP, TRANSLATABLE, null,
                                  TRANSLATABLE, on_flip_vertically
                                };
        vflip.label = Resources.VFLIP_MENU;
        vflip.tooltip = Resources.VFLIP_TOOLTIP;
        actions += vflip;

        Gtk.ActionEntry copy_adjustments = { "CopyColorAdjustments", null, TRANSLATABLE,
                                             "<Ctrl><Shift>C", TRANSLATABLE, on_copy_adjustments
                                           };
        copy_adjustments.label = Resources.COPY_ADJUSTMENTS_MENU;
        copy_adjustments.tooltip = Resources.COPY_ADJUSTMENTS_TOOLTIP;
        actions += copy_adjustments;

        Gtk.ActionEntry paste_adjustments = { "PasteColorAdjustments", null, TRANSLATABLE,
                                              "<Ctrl><Shift>V", TRANSLATABLE, on_paste_adjustments
                                            };
        paste_adjustments.label = Resources.PASTE_ADJUSTMENTS_MENU;
        paste_adjustments.tooltip = Resources.PASTE_ADJUSTMENTS_TOOLTIP;
        actions += paste_adjustments;

        Gtk.ActionEntry revert = { "Revert", Gtk.Stock.REVERT_TO_SAVED, TRANSLATABLE, null,
                                   TRANSLATABLE, on_revert
                                 };
        revert.label = Resources.REVERT_MENU;
        actions += revert;

        Gtk.ActionEntry duplicate = { "Duplicate", null, TRANSLATABLE, "<Ctrl>D", TRANSLATABLE,
                                      on_duplicate_photo
                                    };
        duplicate.label = Resources.DUPLICATE_PHOTO_MENU;
        duplicate.tooltip = Resources.DUPLICATE_PHOTO_TOOLTIP;
        actions += duplicate;

        Gtk.ActionEntry adjust_date_time = { "AdjustDateTime", null, TRANSLATABLE, null,
                                             TRANSLATABLE, on_adjust_date_time
                                           };
        adjust_date_time.label = Resources.ADJUST_DATE_TIME_MENU;
        actions += adjust_date_time;

        Gtk.ActionEntry open_with = { "OpenWith", null, TRANSLATABLE, null, null, null };
        open_with.label = Resources.OPEN_WITH_MENU;
        actions += open_with;

        Gtk.ActionEntry open_with_raw = { "OpenWithRaw", null, TRANSLATABLE, null, null, null };
        open_with_raw.label = Resources.OPEN_WITH_RAW_MENU;
        actions += open_with_raw;

        Gtk.ActionEntry enhance = { "Enhance", Resources.ENHANCE, TRANSLATABLE, "<Ctrl>E",
                                    TRANSLATABLE, on_enhance
                                  };
        enhance.label = Resources.ENHANCE_MENU;
        enhance.tooltip = Resources.ENHANCE_TOOLTIP;
        actions += enhance;

        Gtk.ActionEntry slideshow = { "Slideshow", null, TRANSLATABLE, "F5", TRANSLATABLE,
                                      on_slideshow
                                    };
        slideshow.label = _ ("S_lideshow");
        slideshow.tooltip = _ ("Play a slideshow");
        actions += slideshow;

        return actions;
    }

    protected override InjectionGroup[] init_collect_injection_groups () {
        InjectionGroup[] groups = base.init_collect_injection_groups ();

        groups += create_file_menu_injectables ();
        groups += create_context_menu_injectables ();
        groups += create_view_menu_fullscreen_injectables ();

        return groups;
    }

    public override Gtk.Menu? get_item_context_menu () {
        Gtk.Menu menu = (Gtk.Menu) ui.get_widget ("/CollectionContextMenu");
        assert (menu != null);

        Gtk.MenuItem open_with_menu_item = (Gtk.MenuItem) ui.get_widget ("/CollectionContextMenu/OpenWith");
        populate_external_app_menu ((Gtk.Menu)open_with_menu_item.get_submenu (), false);
        open_with_menu_item.show ();

        if (((Photo) get_view ().get_selected_at (0).get_source ()).get_master_file_format () == PhotoFileFormat.RAW) {
            Gtk.MenuItem open_with_raw_menu_item = (Gtk.MenuItem) ui.get_widget ("/CollectionContextMenu/OpenWithRaw");
            populate_external_app_menu ((Gtk.Menu)open_with_raw_menu_item.get_submenu (), true);
            open_with_raw_menu_item.show ();
        }

        populate_contractor_menu (menu, "/CollectionContextMenu/ContractorPlaceholder");
        populate_rating_widget_menu_item (menu, "/CollectionContextMenu/RatingWidgetPlaceholder");
        update_rating_sensitivities ();
        menu.show_all ();
        return menu;
    }

    private void populate_external_app_menu (Gtk.Menu menu, bool raw) {
        Gtk.MenuItem parent = menu.get_attach_widget () as Gtk.MenuItem;
        SortedList<AppInfo> external_apps;
        string[] mime_types;

        // get list of all applications for the given mime types
        if (raw)
            mime_types = PhotoFileFormat.RAW.get_mime_types ();
        else
            mime_types = PhotoFileFormat.get_editable_mime_types ();
        assert (mime_types.length != 0);
        external_apps = DesktopIntegration.get_apps_for_mime_types (mime_types);

        if (external_apps.size == 0) {
            parent.sensitive = false;
            return;
        }

        foreach (Gtk.Widget item in menu.get_children ())
            menu.remove (item);
        parent.sensitive = true;

        foreach (AppInfo app in external_apps) {
            Gtk.ImageMenuItem item_app = new Gtk.ImageMenuItem.with_label (app.get_name ());
            Gtk.Image image = new Gtk.Image.from_gicon (app.get_icon (), Gtk.IconSize.MENU);
            item_app.always_show_image = true;
            item_app.set_image (image);
            item_app.activate.connect (() => {
                if (raw)
                    on_open_with_raw (app.get_commandline ());
                else
                    on_open_with (app.get_commandline ());
            });
            menu.add (item_app);
        }
        menu.show_all ();
    }

    private void on_open_with (string app) {
        if (get_view ().get_selected_count () != 1)
            return;

        Photo photo = (Photo) get_view ().get_selected_at (0).get_source ();
        try {
            AppWindow.get_instance ().set_busy_cursor ();
            photo.open_with_external_editor (app);
            AppWindow.get_instance ().set_normal_cursor ();
        } catch (Error err) {
            AppWindow.get_instance ().set_normal_cursor ();
            open_external_editor_error_dialog (err, photo);
        }
    }

    private void on_open_with_raw (string app) {
        if (get_view ().get_selected_count () != 1)
            return;

        Photo photo = (Photo) get_view ().get_selected_at (0).get_source ();
        if (photo.get_master_file_format () != PhotoFileFormat.RAW)
            return;

        try {
            AppWindow.get_instance ().set_busy_cursor ();
            photo.open_with_raw_external_editor (app);
            AppWindow.get_instance ().set_normal_cursor ();
        } catch (Error err) {
            AppWindow.get_instance ().set_normal_cursor ();
            AppWindow.error_message (Resources.launch_editor_failed (err));
        }
    }

    private bool selection_has_video () {
        return MediaSourceCollection.has_video ((Gee.Collection<MediaSource>) get_view ().get_selected_sources ());
    }

    private bool page_has_photo () {
        return MediaSourceCollection.has_photo ((Gee.Collection<MediaSource>) get_view ().get_sources ());
    }

    private bool selection_has_photo () {
        return MediaSourceCollection.has_photo ((Gee.Collection<MediaSource>) get_view ().get_selected_sources ());
    }

    protected override void init_actions (int selected_count, int count) {
        base.init_actions (selected_count, count);

        set_action_short_label ("RotateClockwise", Resources.ROTATE_CW_LABEL);
        set_action_short_label ("RotateCounterclockwise", Resources.ROTATE_CCW_LABEL);
        set_action_short_label ("Publish", Resources.PUBLISH_LABEL);

        set_action_important ("RotateClockwise", true);
        set_action_important ("RotateCounterclockwise", true);
        set_action_important ("Enhance", true);
        set_action_important ("Publish", true);
    }

    protected override void update_actions (int selected_count, int count) {
        base.update_actions (selected_count, count);

        bool one_selected = selected_count == 1;
        bool has_selected = selected_count > 0;

        bool primary_is_video = false;
        if (has_selected)
            if (get_view ().get_selected_at (0).get_source () is Video)
                primary_is_video = true;

        bool selection_has_videos = selection_has_video ();
        bool page_has_photos = page_has_photo ();

        // don't allow duplication of the selection if it contains a video -- videos are huge and
        // and they're not editable anyway, so there seems to be no use case for duplicating them
        set_action_sensitive ("Duplicate", has_selected && (!selection_has_videos));
        set_action_visible ("OpenWith", (!primary_is_video));
        set_action_sensitive ("OpenWith", one_selected);
        set_action_visible ("OpenWithRaw",
                            one_selected && (!primary_is_video)
                            && ((Photo) get_view ().get_selected_at (0).get_source ()).get_master_file_format () ==
                            PhotoFileFormat.RAW);
        set_action_sensitive ("Revert", (!selection_has_videos) && can_revert_selected ());
        set_action_sensitive ("Enhance", (!selection_has_videos) && has_selected);
        set_action_sensitive ("CopyColorAdjustments", (!selection_has_videos) && one_selected &&
                              ((Photo) get_view ().get_selected_at (0).get_source ()).has_color_adjustments ());
        set_action_sensitive ("PasteColorAdjustments", (!selection_has_videos) && has_selected &&
                              PixelTransformationBundle.has_copied_color_adjustments ());
        set_action_sensitive ("RotateClockwise", (!selection_has_videos) && has_selected);
        set_action_sensitive ("RotateCounterclockwise", (!selection_has_videos) && has_selected);
        set_action_sensitive ("FlipHorizontally", (!selection_has_videos) && has_selected);
        set_action_sensitive ("FlipVertically", (!selection_has_videos) && has_selected);

        // Allow changing of exposure time, even if there's a video in the current
        // selection.
        set_action_sensitive ("AdjustDateTime", has_selected);

        set_action_sensitive ("NewEvent", has_selected);
        set_action_sensitive ("Slideshow", page_has_photos && (!primary_is_video));
        set_action_sensitive ("Print", (!selection_has_videos) && has_selected);
        set_action_sensitive ("Publish", has_selected);
        enhance_button.sensitive = (!selection_has_videos) && has_selected;
        update_enhance_toggled ();
    }

    private void on_photos_altered (Gee.Map<DataObject, Alteration> altered) {
        // only check for revert if the media object is a photo and its image has changed in some
        // way and it's in the selection
        foreach (DataObject object in altered.keys) {
            DataView view = (DataView) object;

            if (!view.is_selected () || !altered.get (view).has_subject ("image"))
                continue;

            LibraryPhoto? photo = view.get_source () as LibraryPhoto;
            if (photo == null)
                continue;

            // since the photo can be altered externally to Shotwell now, need to make the revert
            // command available appropriately, even if the selection doesn't change
            set_action_sensitive ("Revert", can_revert_selected ());
            set_action_sensitive ("CopyColorAdjustments", photo.has_color_adjustments ());
            update_enhance_toggled ();
            break;
        }
    }

    private void update_enhance_toggled () {
        bool toggled = false;
        foreach (DataView view in get_view ().get_selected ()) {
            Photo photo = view.get_source () as Photo;
            if (photo != null && !photo.is_enhanced ()) {
                toggled = false;
                break;
            }
            else if (photo != null)
                toggled = true;
        }

        enhance_button.clicked.disconnect (on_enhance);
        enhance_button.active = toggled;
        enhance_button.clicked.connect (on_enhance);

        Gtk.Action? action = get_action ("Enhance");
        assert (action != null);
        action.label = toggled ? Resources.UNENHANCE_MENU : Resources.ENHANCE_MENU;

    }

    private void on_print () {
        if (get_view ().get_selected_count () > 0) {
            PrintManager.get_instance ().spool_photo (
                (Gee.Collection<Photo>) get_view ().get_selected_sources_of_type (typeof (Photo)));
        }
    }

    // see #2020
    // double clcik = switch to photo page
    // Super + double click = open in external editor
    // Enter = switch to PhotoPage
    // Ctrl + Enter = open in external editor (handled with accelerators)
    // Shift + Ctrl + Enter = open in external RAW editor (handled with accelerators)
    protected override void on_item_activated (CheckerboardItem item, CheckerboardPage.Activator
            activator, CheckerboardPage.KeyboardModifiers modifiers) {
        Thumbnail thumbnail = (Thumbnail) item;

        // none of the fancy Super, Ctrl, Shift, etc., keyboard accelerators apply to videos,
        // since they can't be RAW files or be opened in an external editor, etc., so if this is
        // a video, just play it and do a short-circuit return
        if (thumbnail.get_media_source () is Video) {
            on_play_video ();
            return;
        }

        LibraryPhoto? photo = thumbnail.get_media_source () as LibraryPhoto;
        if (photo == null)
            return;

        // switch to full-page view or open in external editor
        debug ("activating %s", photo.to_string ());

        if (activator == CheckerboardPage.Activator.MOUSE) {
            if (modifiers.super_pressed)
                //last used
                on_open_with (Config.Facade.get_instance ().get_external_photo_app ());
            else
                LibraryWindow.get_app ().switch_to_photo_page (this, photo);
        } else if (activator == CheckerboardPage.Activator.KEYBOARD) {
            if (!modifiers.shift_pressed && !modifiers.ctrl_pressed)
                LibraryWindow.get_app ().switch_to_photo_page (this, photo);
        }
    }

    protected override bool on_app_key_pressed (Gdk.EventKey event) {
        bool handled = true;
        switch (Gdk.keyval_name (event.keyval)) {
        case "Page_Up":
        case "KP_Page_Up":
        case "Page_Down":
        case "KP_Page_Down":
        case "Home":
        case "KP_Home":
        case "End":
        case "KP_End":
            key_press_event (event);
            break;
        case "bracketright":
            activate_action ("RotateClockwise");
            break;

        case "bracketleft":
            activate_action ("RotateCounterclockwise");
            break;

        default:
            handled = false;
            break;
        }

        return handled ? true : base.on_app_key_pressed (event);
    }

    protected override void on_export () {
        if (exporter != null)
            return;

        Gee.Collection<MediaSource> export_list =
            (Gee.Collection<MediaSource>) get_view ().get_selected_sources ();
        if (export_list.size == 0)
            return;

        bool has_some_photos = selection_has_photo ();
        bool has_some_videos = selection_has_video ();
        assert (has_some_photos || has_some_videos);

        // if we don't have any photos, then everything is a video, so skip displaying the Export
        // dialog and go right to the video export operation
        if (!has_some_photos) {
            exporter = Video.export_many ((Gee.Collection<Video>) export_list, on_export_completed);
            return;
        }

        string title = null;
        if (has_some_videos)
            title = (export_list.size == 1) ? _ ("Export Photo/Video") : _ ("Export Photos/Videos");
        else
            title = (export_list.size == 1) ?  _ ("Export Photo") : _ ("Export Photos");
        ExportDialog export_dialog = new ExportDialog (title);

        // Setting up the parameters object requires a bit of thinking about what the user wants.
        // If the selection contains only photos, then we do what we've done in previous versions
        // of Shotwell -- we use whatever settings the user selected on his last export operation
        // (the thinking here being that if you've been exporting small PNGs for your blog
        // for the last n export operations, then it's likely that for your (n + 1)-th export
        // operation you'll also be exporting a small PNG for your blog). However, if the selection
        // contains any videos, then we set the parameters to the "Current" operating mode, since
        // videos can't be saved as PNGs (or any other specific photo format).
        ExportFormatParameters export_params = (has_some_videos) ? ExportFormatParameters.current () :
                                               ExportFormatParameters.last ();

        int scale;
        ScaleConstraint constraint;
        if (!export_dialog.execute (out scale, out constraint, ref export_params))
            return;

        Scaling scaling = Scaling.for_constraint (constraint, scale, false);

        // handle the single-photo case, which is treated like a Save As file operation
        if (export_list.size == 1) {
            LibraryPhoto photo = null;
            foreach (LibraryPhoto p in (Gee.Collection<LibraryPhoto>) export_list) {
                photo = p;
                break;
            }

            File save_as =
                ExportUI.choose_file (photo.get_export_basename_for_parameters (export_params));
            if (save_as == null)
                return;

            try {
                AppWindow.get_instance ().set_busy_cursor ();
                photo.export (save_as, scaling, export_params.quality,
                              photo.get_export_format_for_parameters (export_params), export_params.mode ==
                              ExportFormatMode.UNMODIFIED, export_params.export_metadata);
                AppWindow.get_instance ().set_normal_cursor ();
            } catch (Error err) {
                AppWindow.get_instance ().set_normal_cursor ();
                export_error_dialog (save_as, false);
            }

            return;
        }

        // multiple photos or videos
        File export_dir = ExportUI.choose_dir (title);
        if (export_dir == null)
            return;

        exporter = new ExporterUI (new Exporter (export_list, export_dir, scaling, export_params));
        exporter.export (on_export_completed);
    }

    private void on_export_completed () {
        exporter = null;
    }

    private bool can_revert_selected () {
        foreach (DataSource source in get_view ().get_selected_sources ()) {
            LibraryPhoto? photo = source as LibraryPhoto;
            if (photo != null && (photo.has_transformations () || photo.has_editable ()))
                return true;
        }

        return false;
    }

    private bool can_revert_editable_selected () {
        foreach (DataSource source in get_view ().get_selected_sources ()) {
            LibraryPhoto? photo = source as LibraryPhoto;
            if (photo != null && photo.has_editable ())
                return true;
        }

        return false;
    }

    private void on_show_sidebar () {
        var app = AppWindow.get_instance () as LibraryWindow;
        app.set_metadata_sidebar_visible (!app.is_metadata_sidebar_visible ());
        update_sidebar_action (!app.is_metadata_sidebar_visible ());
    }

    private void on_rotate_clockwise () {
        if (get_view ().get_selected_count () == 0)
            return;

        RotateMultipleCommand command = new RotateMultipleCommand (get_view ().get_selected (),
                Rotation.CLOCKWISE, Resources.ROTATE_CW_FULL_LABEL, Resources.ROTATE_CW_TOOLTIP,
                _ ("Rotating"), _ ("Undoing Rotate"));
        get_command_manager ().execute (command);
    }

    private void on_publish () {
        if (get_view ().get_selected_count () > 0)
            PublishingUI.PublishingDialog.go (
                (Gee.Collection<MediaSource>) get_view ().get_selected_sources ());
    }

    private void on_rotate_counterclockwise () {
        if (get_view ().get_selected_count () == 0)
            return;

        RotateMultipleCommand command = new RotateMultipleCommand (get_view ().get_selected (),
                Rotation.COUNTERCLOCKWISE, Resources.ROTATE_CCW_FULL_LABEL, Resources.ROTATE_CCW_TOOLTIP,
                _ ("Rotating"), _ ("Undoing Rotate"));
        get_command_manager ().execute (command);
    }

    private void on_flip_horizontally () {
        if (get_view ().get_selected_count () == 0)
            return;

        RotateMultipleCommand command = new RotateMultipleCommand (get_view ().get_selected (),
                Rotation.MIRROR, Resources.HFLIP_LABEL, "", _ ("Flipping Horizontally"),
                _ ("Undoing Flip Horizontally"));
        get_command_manager ().execute (command);
    }

    private void on_flip_vertically () {
        if (get_view ().get_selected_count () == 0)
            return;

        RotateMultipleCommand command = new RotateMultipleCommand (get_view ().get_selected (),
                Rotation.UPSIDE_DOWN, Resources.VFLIP_LABEL, "", _ ("Flipping Vertically"),
                _ ("Undoing Flip Vertically"));
        get_command_manager ().execute (command);
    }

    private void on_revert () {
        if (get_view ().get_selected_count () == 0)
            return;

        if (can_revert_editable_selected ()) {
            if (!revert_editable_dialog (AppWindow.get_instance (),
                                         (Gee.Collection<Photo>) get_view ().get_selected_sources ())) {
                return;
            }

            foreach (DataObject object in get_view ().get_selected_sources ())
                ((Photo) object).revert_to_master ();
        }

        RevertMultipleCommand command = new RevertMultipleCommand (get_view ().get_selected ());
        get_command_manager ().execute (command);
    }

    public void on_copy_adjustments () {
        if (get_view ().get_selected_count () != 1)
            return;
        Photo photo = (Photo) get_view ().get_selected_at (0).get_source ();
        PixelTransformationBundle.set_copied_color_adjustments (photo.get_color_adjustments ());
        set_action_sensitive ("PasteColorAdjustments", true);
    }

    public void on_paste_adjustments () {
        PixelTransformationBundle? copied_adjustments = PixelTransformationBundle.get_copied_color_adjustments ();
        if (get_view ().get_selected_count () == 0 || copied_adjustments == null)
            return;

        AdjustColorsMultipleCommand command = new AdjustColorsMultipleCommand (get_view ().get_selected (),
                copied_adjustments, Resources.PASTE_ADJUSTMENTS_LABEL, Resources.PASTE_ADJUSTMENTS_TOOLTIP);
        get_command_manager ().execute (command);
    }

    private void on_enhance () {
        if (get_view ().get_selected_count () == 0)
            return;
            
        /* If one photo in the selection is unenhanced, set the enhance button to untoggled. 
          We also just want to execute the enhance command on the unenhanced photo so that
          we can unenhance properly those that were previously enhanced. We also need to sort out non photos */
        Gee.ArrayList<DataView> unenhanced_list = new Gee.ArrayList<DataView> ();
        Gee.ArrayList<DataView> enhanced_list = new Gee.ArrayList<DataView> ();
        foreach (DataView view in get_view () .get_selected ()) {
            Photo photo = view.get_source () as Photo;
            if (photo != null && !photo.is_enhanced ())
                unenhanced_list.add (view);
            else if (photo != null)
                enhanced_list.add (view);
        }

        if (enhanced_list.size == 0 && unenhanced_list.size == 0)
            return;

        if (unenhanced_list.size == 0) {
            // Just undo if last on stack was enhance
            EnhanceMultipleCommand cmd = get_command_manager ().get_undo_description () as EnhanceMultipleCommand;
            if (cmd != null && cmd.source_list == get_view () .get_selected ())
                get_command_manager ().undo ();
            else {
                UnEnhanceMultipleCommand command = new UnEnhanceMultipleCommand (enhanced_list);
                get_command_manager ().execute (command);     
            }
            foreach (DataView view in enhanced_list) {
                Photo photo = view.get_source () as Photo;
                photo.set_enhanced (false);   
            }
        } else {
            // Just undo if last on stack was unenhance
            UnEnhanceMultipleCommand cmd = get_command_manager ().get_undo_description () as UnEnhanceMultipleCommand;
            if (cmd != null && cmd.source_list == get_view () .get_selected ())
                get_command_manager ().undo ();
            else {
                EnhanceMultipleCommand command = new EnhanceMultipleCommand (unenhanced_list);
                get_command_manager ().execute (command);
            }    
            foreach (DataView view in enhanced_list) {
                Photo photo = view.get_source () as Photo;
                photo.set_enhanced (true);   
            }  
        }
        update_enhance_toggled ();
    }

    private void on_duplicate_photo () {
        if (get_view ().get_selected_count () == 0)
            return;

        DuplicateMultiplePhotosCommand command = new DuplicateMultiplePhotosCommand (
            get_view ().get_selected ());
        get_command_manager ().execute (command);
    }

    private void on_adjust_date_time () {
        if (get_view ().get_selected_count () == 0)
            return;

        bool selected_has_videos = false;
        bool only_videos_selected = true;

        foreach (DataView dv in get_view ().get_selected ()) {
            if (dv.get_source () is Video)
                selected_has_videos = true;
            else
                only_videos_selected = false;
        }

        Dateable photo_source = (Dateable) get_view ().get_selected_at (0).get_source ();

        AdjustDateTimeDialog dialog = new AdjustDateTimeDialog (photo_source,
                get_view ().get_selected_count (), true, selected_has_videos, only_videos_selected);

        int64 time_shift;
        bool keep_relativity, modify_originals;
        if (dialog.execute (out time_shift, out keep_relativity, out modify_originals)) {
            AdjustDateTimePhotosCommand command = new AdjustDateTimePhotosCommand (
                get_view ().get_selected (), time_shift, keep_relativity, modify_originals);
            get_command_manager ().execute (command);
        }
    }

    private void on_slideshow () {
        if (get_view ().get_count () == 0)
            return;

        // use first selected photo, else use first photo
        Gee.List<DataSource>? sources = (get_view ().get_selected_count () > 0)
                                        ? get_view ().get_selected_sources_of_type (typeof (LibraryPhoto))
                                        : get_view ().get_sources_of_type (typeof (LibraryPhoto));
        if (sources == null || sources.size == 0)
            return;

        Thumbnail? thumbnail = (Thumbnail? ) get_view ().get_view_for_source (sources[0]);
        if (thumbnail == null)
            return;

        LibraryPhoto? photo = thumbnail.get_media_source () as LibraryPhoto;
        if (photo == null)
            return;

        AppWindow.get_instance ().go_fullscreen (new SlideshowPage (LibraryPhoto.global, get_view (),
                                                photo));
    }

    protected override bool on_ctrl_pressed (Gdk.EventKey? event) {
        Gtk.ToolButton? rotate_button = ui.get_widget ("/CollectionToolbar/ToolRotate")
                                        as Gtk.ToolButton;
        if (rotate_button != null)
            rotate_button.set_related_action (get_action ("RotateCounterclockwise"));

        Gtk.ToolButton? flip_button = ui.get_widget ("/CollectionToolbar/ToolFlip")
                                        as Gtk.ToolButton;
        if (flip_button != null)
            flip_button.set_related_action (get_action ("FlipVertically"));

        return base.on_ctrl_pressed (event);
    }

    protected override bool on_ctrl_released (Gdk.EventKey? event) {
        Gtk.ToolButton? rotate_button = ui.get_widget ("/CollectionToolbar/ToolRotate")
                                        as Gtk.ToolButton;
        if (rotate_button != null)
            rotate_button.set_related_action (get_action ("RotateClockwise"));
            
        Gtk.ToolButton? flip_button = ui.get_widget ("/CollectionToolbar/ToolFlip")
                                        as Gtk.ToolButton;
        if (flip_button != null)
            flip_button.set_related_action (get_action ("FlipHorizontally"));

        return base.on_ctrl_released (event);
    }

    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }
}
