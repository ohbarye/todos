# An example Backbone application contributed by
# [Jérôme Gravel-Niquet](http:#jgn.me/). This demo uses a simple
# [LocalStorage adapter](backbone-localstorage.html)
# to persist Backbone models within your browser.

# Load the application once the DOM is ready, using `jQuery.ready`:
$ ->

  _.templateSettings =
    interpolate: /\{\{(.+?)\}\}/g,
    evaluate: /\{%(.+?)%\}/g,
    escape: /\{%-(.+?)%\}/g

  # Todo Model
  # ----------

  # Our basic **Todo** model has `title`, `order`, and `done` attributes.
  class Todo extends Backbone.Model

    # Default attributes for the todo item.
    defaults: ->
      title: "empty todo..."
      order: Todos.nextOrder()
      done: false

    # Ensure that each todo created has `title`.
    initialize: ->
      if !@get("title")
        @set("title": @defaults().title)

    # Toggle the `done` state of this todo item.
    toggle: ->
      @save(done: !@get("done"))

  # Todo Collection
  # ---------------

  # The collection of todos is backed by *localStorage* instead of a remote
  # server.
  class TodoList extends Backbone.Collection

    # Reference to this collection's model.
    model: Todo

    # Save all of the todo items to database.
    url: "/todos"

    # Filter down the list of all todo items that are finished.
    done: ->
      @filter(
        (todo) ->
          return todo.get('done')
      )

    # Filter down the list to only todo items that are still not finished.
    remaining: ->
      return @without.apply(this, @done())

    # We keep the Todos in sequential order, despite being saved by unordered
    # GUID in the database. This generates the next order number for new items.
    nextOrder: ->
      if !@length then return 1
      return @last().get('order') + 1

    # Todos are sorted by their original insertion order.
    comparator: (todo) ->
      return todo.get('order')

  # Create our global collection of **Todos**.
  Todos = new TodoList

  # Todo Item View
  # --------------

  # The DOM element for a todo item...
  class TodoView extends Backbone.View

    #... is a list tag.
    tagName:  "li"

    # Cache the template function for a single item.
    template: _.template($('#item-template').html())

    # The DOM events specific to an item.
    events:
      "click .toggle"   : "toggleDone"
      "dblclick .view"  : "edit"
      "click a.destroy" : "clear"
      "keypress .edit"  : "updateOnEnter"
      "blur .edit"      : "close"

    # The TodoView listens for changes to its model, re-rendering. Since there's
    # a one-to-one correspondence between a **Todo** and a **TodoView** in this
    # app, we set a direct reference on the model for convenience.
    initialize: ->
      @listenTo(@model, 'change', @render)
      @listenTo(@model, 'destroy', @remove)

    # Re-render the titles of the todo item.
    render: ->
      @$el.html(@template(@model.toJSON()))
      @$el.toggleClass('done', @model.get('done'))
      @input = @$('.edit')
      return this

    # Toggle the `"done"` state of the model.
    toggleDone: ->
      @model.toggle()

    # Switch this view into `"editing"` mode, displaying the input field.
    edit: ->
      @$el.addClass("editing")
      @input.focus()

    # Close the `"editing"` mode, saving changes to the todo.
    close: ->
      value = @input.val()
      if !value
        @clear()
      else
        @model.save(title: value)
        @$el.removeClass("editing")

    # If you hit `enter`, we're through editing the item.
    updateOnEnter: (e) ->
      if e.keyCode == 13 then @close()

    # Remove the item, destroy the model.
    clear: ->
      @model.destroy()

  # The Application
  # ---------------

  # Our overall **AppView** is the top-level piece of UI.
  class AppView extends Backbone.View

    # Instead of generating a new element, bind to the existing skeleton of
    # the App already present in the HTML.
    el: $("#todoapp")

    # Our template for the line of statistics at the bottom of the app.
    statsTemplate: _.template($('#stats-template').html())

    # Delegated events for creating new items, and clearing completed ones.
    events:
      "keypress #new-todo":  "createOnEnter"
      "click #clear-completed": "clearCompleted"
      "click #toggle-all": "toggleAllComplete"

    # At initialization we bind to the relevant events on the `Todos`
    # collection, when items are added or changed. Kick things off by
    # loading any preexisting todos that might be saved in *localStorage*.
    initialize: ->

      @input = @$("#new-todo")
      @allCheckbox = @$("#toggle-all")[0]

      @listenTo(Todos, 'add', @addOne)
      @listenTo(Todos, 'reset', @addAll)
      @listenTo(Todos, 'all', @render)

      @footer = @$('footer')
      @main = $('#main')

      Todos.fetch()

    # Re-rendering the App just means refreshing the statistics -- the rest
    # of the app doesn't change.
    render: ->
      done = Todos.done().length
      remaining = Todos.remaining().length

      if Todos.length
        @main.show()
        @footer.show()
        @footer.html(@statsTemplate(
          done: done
          remaining: remaining
        ))
      else
        @main.hide()
        @footer.hide()

      @allCheckbox.checked = !remaining

    # Add a single todo item to the list by creating a view for it, and
    # appending its element to the `<ul>`.
    addOne: (todo) ->
      view = new TodoView(model: todo)
      @$("#todo-list").append(view.render().el)

    # Add all items in the **Todos** collection at once.
    addAll: ->
      Todos.each(@addOne, this)

    # If you hit return in the main input field, create new **Todo** model,
    # persisting it to *localStorage*.
    createOnEnter: (e) ->
      if e.keyCode != 13 then return
      if !@input.val() then return

      Todos.create(title: @input.val())
      @input.val('')

    # Clear all done todo items, destroying their models.
    clearCompleted: ->
      _.invoke(Todos.done(), 'destroy')
      return false

    toggleAllComplete: ->
      done = @allCheckbox.checked
      Todos.each(
        (todo) ->
          todo.save('done': done)
      )

  # Finally, we kick things off by creating the **App**.
  App = new AppView
