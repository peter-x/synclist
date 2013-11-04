User Interface
==============

The UserInterface uses jquerymobile to style its html elements, is a change
observer of the manager and actually changes the items on the user's request.
Apart from the constructor, it has no public methods.

    class UserInterface
        constructor: (@_manager) ->
            @_initializeUI()
            @_suppressRefreshCalls = true
            @_onItemChanged item for id, item of @_manager.getItems()
            @_suppressRefreshCalls = false
            $('#items').listview('refresh')
            @_manager.onChange (item) => @_onItemChanged item

Private Methods
---------------

Find all relevant html elements and register callbacks.

        _initializeUI: () ->
            $('#categorySelector').change () =>
                @_showHideBasedOnCategory($('.item'))
            $('#newItem').click () =>
                text = window.prompt("Text")
                if text?
                    @_manager.saveItem Item.createNew(text, @_currentCategory())

        _currentCategory: () ->
            $('#categorySelector').val()

        _showHideBasedOnCategory: (items,
                                   category = @_currentCategory()) ->
            showCondition = (e) -> category == '' or $(e).data('category') == category
            items.filter( -> not showCondition(@)).hide()
            items.filter( -> showCondition(@)).show()

Apply changes found in the database. This also applies changes made by the user
after they went through the database.

        _onItemChanged: (item) ->
            element = $('#item_' + item.getID())
            element = @_createElement(item.getID()) if element.length == 0
            $('.text', element).text(item.getText())
            element.data('category', item.getCategory())
            @_showHideBasedOnCategory(element)
            $('#items').listview('refresh') unless @_suppressRefreshCalls
            element.data('icon', 'check') if item.getResolved()

            # TODO resolved, position

Create a simple html element that provides everything that is needed to display
an item.

        _createElement: (id) ->
            $('<li class="item" data-icon="false"><a class="text" href="#"></a></li>')
                .attr('id', 'item_' + id)
                .appendTo('#items')
                .click => @_itemClicked id

Handle a click on an item, currently this is used to change the text. It is
important to first retrieve the item so that concurrent changes are not lost but
merged.

        _itemClicked: (id) ->
            item = @_manager.getItems()[id]
            if item?
                text = window.prompt("Text", item.getText())
                if text?
                    @_manager.saveItem item.setText(text)

Export the Interface
--------------------
    (exports ? this).UserInterface = UserInterface
