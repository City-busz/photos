/* Copyright 2011 Yorba Foundation
 *
 * This software is licensed under the GNU LGPL (version 2.1 or later).
 * See the COPYING file in this distribution. 
 */

// This dialog displays a boolean search configuration.
public class SavedSearchDialog {
    
    // Conatins a search row, with a type selector and remove button.
    private class SearchRowContainer {
        public signal void remove(SearchRowContainer this_row);
        
        private Gtk.ComboBox type_combo;
        private Gtk.HBox box;
        private Gtk.Alignment align;
        private Gtk.Button remove_button;
        
        private SearchRow? my_row = null;
        
        public SearchRowContainer() {
            setup_gui();
            set_type(SearchCondition.SearchType.ANY_TEXT);
        }
        
        public SearchRowContainer.edit_existing(SearchCondition sc) {
            setup_gui();
            set_type(sc.search_type);
            type_combo.set_active(sc.search_type);
            my_row.populate(sc);
        }
        
        // Creates the GUI for this row.
        private void setup_gui() {
            // Ordering must correspond with SearchCondition.SearchType
            type_combo = new Gtk.ComboBox.text();
            type_combo.append_text(_("Any text"));
            type_combo.append_text(_("Title"));
            type_combo.append_text(_("Tag"));
            type_combo.append_text(_("Event name"));
            type_combo.append_text(_("File name"));
            type_combo.append_text(_("Media type"));
            type_combo.append_text(_("Flag state"));
            type_combo.append_text(_("Rating"));
            type_combo.set_active(0); // Sets default.
            type_combo.changed.connect(on_type_changed);
            
            remove_button = new Gtk.Button();
            remove_button.set_label(" – ");
            remove_button.button_press_event.connect(on_removed);
            
            align = new Gtk.Alignment(0,0,0,0);
        
            box = new Gtk.HBox(false, 8);
            box.pack_start(type_combo, false, false, 0);
            box.pack_start(align, false, false, 0);
            box.pack_start(new Gtk.Alignment(0,0,0,0), true, true, 0); // Fill space.
            box.pack_start(remove_button, false, false, 0);
            box.show_all();
        }
        
        private void on_type_changed() {
            set_type(get_search_type());
        }
        
        private void set_type(SearchCondition.SearchType type) {
            if (my_row != null)
                align.remove(my_row.get_widget());
            
            switch (type) {
                case SearchCondition.SearchType.ANY_TEXT:
                case SearchCondition.SearchType.EVENT_NAME:
                case SearchCondition.SearchType.FILE_NAME:
                case SearchCondition.SearchType.TAG:
                case SearchCondition.SearchType.TITLE:
                    my_row = new SearchRowText(this);
                    break;
                    
                case SearchCondition.SearchType.MEDIA_TYPE:
                    my_row = new SearchRowMediaType(this);
                    break;
                    
                case SearchCondition.SearchType.FLAG_STATE:
                    my_row = new SearchRowFlagged(this);
                    break;
                
                case SearchCondition.SearchType.RATING:
                    my_row = new SearchRowRating(this);
                    break;
                    
                default:
                    assert(false);
                    break;
            }
            
            align.add(my_row.get_widget());
        }
        
        public SearchCondition.SearchType get_search_type() {
            return (SearchCondition.SearchType) type_combo.get_active();
        }
        
        private bool on_removed(Gdk.EventButton event) {
            remove(this);
            return false;
        }
        
        public void allow_removal(bool allow) {
            remove_button.sensitive = allow;
        }
        
        public Gtk.Widget get_widget() {
            return box;
        }
        
        public SearchCondition get_search_condition() {
            return my_row.get_search_condition();
        }
    }
    
    // Represents a row-type.
    private abstract class SearchRow {
        // Returns the GUI widget for this row. 
        public abstract Gtk.Widget get_widget();
        
        // Returns the search condition for this row.
        public abstract SearchCondition get_search_condition();
        
        // Fills out the fields in this row based on an existing search condition (for edit mode.)
        public abstract void populate(SearchCondition sc);
    }
    
    private class SearchRowText : SearchRow {
        private Gtk.HBox box;
        private Gtk.ComboBox text_context;
        private Gtk.Entry entry;
        
        private SearchRowContainer parent;
        
        public SearchRowText(SearchRowContainer parent) {
            this.parent = parent;
            
            // Ordering must correspond with SearchConditionText.Context
            text_context = new Gtk.ComboBox.text();
            text_context.append_text(_("contains"));
            text_context.append_text(_("is exactly"));
            text_context.append_text(_("starts with"));
            text_context.append_text(_("ends with"));
            text_context.append_text(_("does not contain"));
            text_context.append_text(_("is not set"));
            text_context.set_active(0);
            
            entry = new Gtk.Entry();
            entry.set_width_chars(25);
            entry.set_activates_default(true);
            
            box = new Gtk.HBox(false, 8);
            box.pack_start(text_context, false, false, 0);
            box.pack_start(entry, false, false, 0);
            box.show_all();
        }
        
        public override Gtk.Widget get_widget() {
            return box;
        }
        
        public override SearchCondition get_search_condition() {
            SearchCondition.SearchType type = parent.get_search_type();
            string text = entry.get_text();
            SearchConditionText.Context context = (SearchConditionText.Context) text_context.get_active();
            SearchConditionText c = new SearchConditionText(type, text, context);
            return c;
        }
        
        public override void populate(SearchCondition sc) {
            SearchConditionText? text = sc as SearchConditionText;
            assert(text != null);
            text_context.set_active(text.context);
            entry.set_text(text.text);
        }
    }
    
    private class SearchRowMediaType : SearchRow {
        private Gtk.HBox box;
        private Gtk.ComboBox media_context;
        private Gtk.ComboBox media_type;
        
        private SearchRowContainer parent;
        
        public SearchRowMediaType(SearchRowContainer parent) {
            this.parent = parent;
            
            // Ordering must correspond with SearchConditionMediaType.Context
            media_context = new Gtk.ComboBox.text();
            media_context.append_text(_("is"));
            media_context.append_text(_("is not"));
            media_context.set_active(0);
            
            // Ordering must correspond with SearchConditionMediaType.MediaType
            media_type = new Gtk.ComboBox.text();
            media_type.append_text(_("any photo"));
            media_type.append_text(_("a raw photo"));
            media_type.append_text(_("a video"));
            media_type.set_active(0);
            
            box = new Gtk.HBox(false, 8);
            box.pack_start(media_context, false, false, 0);
            box.pack_start(media_type, false, false, 0);
            box.show_all();
        }
        
        public override Gtk.Widget get_widget() {
            return box;
        }
        
        public override SearchCondition get_search_condition() {
            SearchCondition.SearchType search_type = parent.get_search_type();
            SearchConditionMediaType.Context context = (SearchConditionMediaType.Context) media_context.get_active();
            SearchConditionMediaType.MediaType type = (SearchConditionMediaType.MediaType) media_type.get_active();
            SearchConditionMediaType c = new SearchConditionMediaType(search_type, context, type);
            return c;
        }
        
        public override void populate(SearchCondition sc) {
            SearchConditionMediaType? media = sc as SearchConditionMediaType;
            assert(media != null);
            media_context.set_active(media.context);
            media_type.set_active(media.media_type);
        }
    }
    
    private class SearchRowFlagged : SearchRow {
        private Gtk.HBox box;
        private Gtk.ComboBox flagged_state;
        
        private SearchRowContainer parent;
        
        public SearchRowFlagged(SearchRowContainer parent) {
            this.parent = parent;
            
            // Ordering must correspond with SearchConditionFlagged.State
            flagged_state = new Gtk.ComboBox.text();
            flagged_state.append_text(_("flagged"));
            flagged_state.append_text(_("not flagged"));
            flagged_state.set_active(0);
            
            box = new Gtk.HBox(false, 8);
            box.pack_start(new Gtk.Label(_("is")), false, false, 0);
            box.pack_start(flagged_state, false, false, 0);
            box.show_all();
        }
        
        public override Gtk.Widget get_widget() {
            return box;
        }
        
        public override SearchCondition get_search_condition() {
            SearchCondition.SearchType search_type = parent.get_search_type();
            SearchConditionFlagged.State state = (SearchConditionFlagged.State) flagged_state.get_active();
            SearchConditionFlagged c = new SearchConditionFlagged(search_type, state);
            return c;
        }
        
        public override void populate(SearchCondition sc) {
            SearchConditionFlagged? f = sc as SearchConditionFlagged;
            assert(f != null);
            flagged_state.set_active(f.state);
        }
    }
    
    private class SearchRowRating : SearchRow {
        private Gtk.HBox box;
        private Gtk.ComboBox rating;
        private Gtk.ComboBox context;
        
        private SearchRowContainer parent;
        
        public SearchRowRating(SearchRowContainer parent) {
            this.parent = parent;
            
            // Ordering must correspond with Rating
            rating = new Gtk.ComboBox.text();
            rating.append_text(Resources.rating_combo_box(Rating.REJECTED));
            rating.append_text(Resources.rating_combo_box(Rating.UNRATED));
            rating.append_text(Resources.rating_combo_box(Rating.ONE));
            rating.append_text(Resources.rating_combo_box(Rating.TWO));
            rating.append_text(Resources.rating_combo_box(Rating.THREE));
            rating.append_text(Resources.rating_combo_box(Rating.FOUR));
            rating.append_text(Resources.rating_combo_box(Rating.FIVE));
            rating.set_active(0);
            
            context = new Gtk.ComboBox.text();
            context.append_text("and higher");
            context.append_text("only");
            context.append_text("and lower");
            context.set_active(0);
            
            box = new Gtk.HBox(false, 8);
            box.pack_start(new Gtk.Label(_("is")), false, false, 0);
            box.pack_start(rating, false, false, 0);
            box.pack_start(context, false, false, 0);
            box.show_all();
        }
        
        public override Gtk.Widget get_widget() {
            return box;
        }
        
        public override SearchCondition get_search_condition() {
            SearchCondition.SearchType search_type = parent.get_search_type();
            Rating search_rating = (Rating) rating.get_active() + Rating.REJECTED;
            SearchConditionRating.Context search_context = (SearchConditionRating.Context) context.get_active();
            SearchConditionRating c = new SearchConditionRating(search_type, search_rating, search_context);
            return c;
        }
        
        public override void populate(SearchCondition sc) {
            SearchConditionRating? r = sc as SearchConditionRating;
            assert(r != null);
            context.set_active(r.context);
            rating.set_active(r.rating - Rating.REJECTED);
        }
    }
    
    private Gtk.Builder builder;
    private Gtk.Dialog dialog;
    private Gtk.Button add_criteria;
    private Gtk.ComboBox operator;
    private Gtk.VBox row_box;
    private Gtk.Entry search_title;
    private Gee.ArrayList<SearchRowContainer> row_list = new Gee.ArrayList<SearchRowContainer>();
    private bool edit_mode = false;
    private SavedSearch? previous_search = null;
    
    public SavedSearchDialog() {
        setup_dialog();
        
        // Default is text search.
        add_text_search();
        row_list.get(0).allow_removal(false);
        
        // Add buttons for new search.
        Gtk.Button ok_button = new Gtk.Button.from_stock(Gtk.Stock.OK);
        ok_button.can_default = true;
        dialog.add_action_widget(ok_button, Gtk.ResponseType.OK);
        dialog.add_action_widget(new Gtk.Button.from_stock(Gtk.Stock.CANCEL), Gtk.ResponseType.CANCEL);
        dialog.set_default_response(Gtk.ResponseType.OK);
        
        dialog.show_all();
    }
    
    public SavedSearchDialog.edit_existing(SavedSearch saved_search) {
        previous_search = saved_search;
        edit_mode = true;
        setup_dialog();
        
        // Load existing search into dialog.
        operator.set_active((SearchOperator) saved_search.get_operator());
        search_title.set_text(saved_search.get_name());
        foreach (SearchCondition sc in saved_search.get_conditions()) {
            add_row(new SearchRowContainer.edit_existing(sc));
        }
        
        if (row_list.size == 1)
            row_list.get(0).allow_removal(false);
        
        // Add close button.
        Gtk.Button close_button = new Gtk.Button.from_stock(Gtk.Stock.CLOSE);
        close_button.can_default = true;
        dialog.add_action_widget(close_button, Gtk.ResponseType.OK);
        dialog.set_default_response(Gtk.ResponseType.OK);
        
        dialog.show_all();
    }
    
    // Builds the dialog UI.  Doesn't add buttons to the dialog or call dialog.show_all().
    private void setup_dialog() {
        builder = AppWindow.create_builder();
        
        dialog = builder.get_object("Search criteria") as Gtk.Dialog;
        dialog.set_parent_window(AppWindow.get_instance().get_parent_window());
        dialog.set_transient_for(AppWindow.get_instance());
        dialog.response.connect(on_response);
        
        add_criteria = builder.get_object("Add search button") as Gtk.Button;
        add_criteria.button_press_event.connect(on_add_criteria);
        
        search_title = builder.get_object("Search title") as Gtk.Entry;
        search_title.set_activates_default(true);
        
        row_box = builder.get_object("row_box") as Gtk.VBox;
        
        operator = builder.get_object("Type of search criteria") as Gtk.ComboBox;
        gtk_combo_box_set_as_text(operator);
        operator.append_text(_("any"));
        operator.append_text(_("all"));
        operator.append_text(_("none"));
        operator.set_active(0);
    }
    
    // Displays the dialog.
    public void show() {
        dialog.run();
        dialog.destroy();
    }
    
    // Adds a row of search criteria.
    private bool on_add_criteria(Gdk.EventButton event) {
        add_text_search();
        return false;
    }
    
    private void add_text_search() {
        SearchRowContainer text = new SearchRowContainer();
        add_row(text);
    }
    
    // Appends a row of search criteria to the list and table.
    private void add_row(SearchRowContainer row) {
        if (row_list.size == 1)
            row_list.get(0).allow_removal(true);
        row_box.add(row.get_widget());
        row_list.add(row);
        row.remove.connect(on_remove_row);
    }
    
    // Removes a row of search criteria.
    private void on_remove_row(SearchRowContainer row) {
        row.remove.disconnect(on_remove_row);
        row_box.remove(row.get_widget());
        row_list.remove(row);
        if (row_list.size == 1)
            row_list.get(0).allow_removal(false);
    }

    private void on_response(int response_id) {
        if (response_id == Gtk.ResponseType.OK) {
            if (SavedSearchTable.get_instance().exists(search_title.get_text()) && 
                !(edit_mode && previous_search.get_name() == search_title.get_text())) {
                AppWindow.error_message(Resources.rename_search_exists_message(search_title.get_text()));
                return;
            }
            
            if (edit_mode) {
                // Remove previous search.
                SavedSearchTable.get_instance().remove(previous_search);
            }
            
            // Build the condition list from the search rows, and add our new saved search to the table.
            Gee.ArrayList<SearchCondition> conditions = new Gee.ArrayList<SearchCondition>();
            foreach (SearchRowContainer c in row_list) {
                conditions.add(c.get_search_condition());
            }
            
            // Create the object.  It will be added to the DB and SearchTable automatically.
            SearchOperator search_operator = (SearchOperator)operator.get_active();
            SavedSearchTable.get_instance().create(search_title.get_text(), search_operator, conditions);
        }
    }
}
