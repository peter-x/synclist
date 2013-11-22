User Interface
==============

The UserInterface uses jquerymobile to style its html elements, is a change
observer of the manager and actually changes the items on the user's request.
Apart from the constructor, it has no public methods.

    class UserInterface
        constructor: (@_manager) ->
            @_currentlyEditingItems = {}
            @_initializeUI()
            @_suppressRefreshCalls = true
            @_onItemChanged item for id, item of @_manager.getItems()
            @_suppressRefreshCalls = false
            $('#items').listview('refresh')
#           $('#items').sortable()
#           $('#items').bind('touchstart', (ev) ->
#           $('#items').sortable()._mouseStart(ev))
#            $('#items').bind('touchmove', (ev) ->
#                $('#items').sortable()._mouseMove(ev))
#            $('#items').bind('touchend', (ev) ->
#                $('#items').sortable()._mouseEnd(ev))
            @_manager.onChange (item) => @_onItemChanged item

Private Methods
---------------

Find all relevant html elements and register callbacks.

        _initializeUI: () ->
            #$('#categorySelector').change () =>
            #    @_showHideBasedOnCategory($('.item'))
            $('#newItem').click () =>
                text = window.prompt("Text")
                if text?
                    @_manager.saveItem Item.createNew(text, @_currentCategory())

        _currentCategory: () ->
            '' #$('#categorySelector').val()

        _showHideBasedOnCategory: (items,
                                   category = @_currentCategory()) ->
            showCondition = (e) -> category == '' or $(e).data('category') == category
            items.filter( -> not showCondition(@)).hide()
            items.filter( -> showCondition(@)).show()

Apply changes found in the database. This also applies changes made by the user
after they went through the database.

        _onItemChanged: (item) ->
            id = item.getID()
            if @_currentlyEditingItems[id]?
                # TODO save this in some queue to apply after edit is done
                return
            element = $('#item_' + id)
            element = @_createElement(id) if element.length == 0
            $('.resolved', element)
                .button({theme: if item.isResolved() then 'b' else 'c'})
            $('.done', element).change( =>
                @_itemResolutionChanged(id, $('.done', element).val()))
            $('.text', element).text(item.getText())
            element.data('category', item.getCategory())
            @_showHideBasedOnCategory(element)
            $('#items').listview('refresh') unless @_suppressRefreshCalls

            # TODO position

Create a html element that provides everything that is needed to display an
item.

        _createElement: (id) ->
            el = $('<li class="item" data-icon="false">' + \
              '<div>' + \
              '<span class="text ui-btn-inline ui-mini" style="height: 24px;"></span>' + \
              '<span style="float: right;">' + \
              '<button class="acceptEdit" data-inline="true" data-mini="true" ' + \
                    'data-icon="check" data-iconpos="notext" />' + \
              '<button class="abortEdit" data-inline="true" data-mini="true" ' + \
                    'data-icon="delete" data-iconpos="notext" />' + \
              '<button class="edit" data-inline="true" data-mini="true" ' + \
                    'data-icon="edit" data-iconpos="notext" />' + \
              '<button class="resolved" data-inline="true" data-mini="true" ' + \
                    'data-icon="check" data-iconpos="notext" />' + \
              '</span>' + \
              '</div>' + \
              '</li>')
                .attr('id', 'item_' + id)
            $('button', el).button()
            $('.resolved', el).click(=> @_toggleItemResolution(id))
            $('.edit', el).click(=> @_editItemClicked(id))
            $('.abortEdit', el)
                .click(=> @_abortEditItemClicked(id))
                .closest('.ui-btn').hide()
            $('.acceptEdit', el)
                .click(=> @_acceptEditItemClicked(id))
                .closest('.ui-btn').hide()
            el.appendTo('#items')

Start editing the item. It is important to first retrieve the item so that
concurrent changes are not lost but merged. After that, show the accept and
abort buttons and position the cursor at the end of the text.

        _editItemClicked: (id) ->
            return if @_currentlyEditingItems[id]?
            item = @_manager.getItems()[id]
            if item?
                @_currentlyEditingItems[id] = item
                @_showEditingButtonState id
                text = $('.text', '#item_' + id)
                text.attr('contenteditable', 'true')
                range = document.createRange()
                range.selectNode(text[0].childNodes[0])
                range.collapse(false)
                sel = window.getSelection()
                sel.removeAllRanges()
                sel.addRange(range)
                text.focus()

Abort editing the item, restore the previous user interface.
TODO: We also have to replay all changes that were made in the meantime.

        _abortEditItemClicked: (id) ->
            item = @_currentlyEditingItems[id]
            delete @_currentlyEditingItems[id]
            if item?
                @_showNonEditingState id
                $('.text', '#item_' + id)
                    .text(item.getText())

Accept the edited text and save the item.

        _acceptEditItemClicked: (id) ->
            item = @_currentlyEditingItems[id]
            delete @_currentlyEditingItems[id]
            if item?
                @_showNonEditingState id
                text = $('.text', '#item_' + id).text()
                @_manager.saveItem item.setText(text)

Set an item to the editing ui state.

        _showEditingButtonState: (id) ->
            $('.abortEdit, .acceptEdit', '#item_' + id)
                .closest('.ui-btn').show()
            $('.edit', '#item_' + id)
                .closest('.ui-btn').hide()

Set the item back to the normal state.

        _showNonEditingState: (id) ->
            $('.text', '#item_' + id)
                .attr('contenteditable', 'false')
                .blur()
            $('.abortEdit, .acceptEdit', '#item_' + id)
                .closest('.ui-btn').hide()
            $('.edit', '#item_' + id)
                .closest('.ui-btn').show()

Called when the user marks an item as resolved or not resolved. To just toggle
the item that is currently in the manager is a bit risky but the user will get
immediate feedback.

        _toggleItemResolution: (id) ->
            item = @_manager.getItems()[id]
            if item?
                @_manager.saveItem item.setResolved(not item.isResolved())


Export the Interface
--------------------
    (exports ? this).UserInterface = UserInterface
