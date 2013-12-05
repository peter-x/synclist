User Interface
==============

The UserInterface uses jquerymobile to style its html elements, is a change
observer of the manager and actually changes the items on the user's request.
Apart from the constructor, it has no public methods.

    class UserInterface
        constructor: (@_manager, @_syncService) ->
            @_currentlyEditingItems = {}
            @_currentlyDraggingItem = undefined
            @_dragStart = [0, 0]
            @_dragCurrent = [0, 0]
            @_showResolved = false
            @_itemHeight = 48

            @_initializeUI()

            @_itemChangeQueue = []
            @_onItemChanged item for id, item of @_manager.getItems()
            @_manager.observe (item) => @_onItemChanged item

            @_syncService.observe (state, errorMessage) =>
                console.log(errorMessage)
                button = $('#syncState')
                button.buttonMarkup({icon: switch state
                    when 'error' then 'delete'
                    when 'waiting' then 'check'
                    else 'throbber'})

Private Methods
---------------

Find all relevant html elements and register callbacks.

        _initializeUI: () ->
            $(document).bind('touchmove mousemove', (event) => @_moveDrag(event))
            $(document).bind('touchend touchcancel mouseup', (ev) => @_endDrag(ev))
            #$('#categorySelector').change () =>
            #    @_updateItemVisibility()
            $('#showResolved').click () =>
                @_showResolved = not @_showResolved
                $('#showResolved').button({theme: if @_showResolved then 'b' else 'c'})
                @_updateItemVisibility()

            $('#newItem').click () =>
                text = window.prompt("Text")
                if text?
                    firstItem = @_itemFromElement($('.item:first'))
                    pos = if firstItem? then firstItem.getPosition() - 1 else 0
                    @_manager.saveItem Item.createNew(text,
                                                      @_currentCategory(),
                                                      pos)
            $('#syncState').click () =>
                @_syncService.fullSync()

        _currentCategory: () ->
            '' #$('#categorySelector').val()

        _updateItemVisibility: (items = $('.item'),
                                category = @_currentCategory()) ->
            showCondition = (e) =>
                item = @_itemFromElement $ e
                (@_showResolved or not item.isResolved()) and \
                    (category == '' or item.getCategory() == category)
            items.filter( -> not showCondition(@)).hide()
            items.filter( -> showCondition(@)).show()

Apply changes found in the database. This also applies changes made by the user
after they went through the database.

        _onItemChanged: (item) ->
            id = item.getID()
            if @_currentlyEditingItems[id]? or @_currentlyDraggingItem?
                @_itemChangeQueue.push(id)
                return
            element = $('#item_' + id)
            element = @_createElement(id) if element.length == 0
            $('.resolved', element)
                .button({theme: if item.isResolved() then 'b' else 'c'})
            $('.done', element).change( =>
                @_itemResolutionChanged(id, $('.done', element).val()))
            $('.item-text', element).text(item.getText())
            element.data('category', item.getCategory())
            @_updateItemVisibility(element)
            @_positionItem(element, item)
            item

        _itemFromElement: (element) ->
            id = element.attr('id')
            if id? and id.match(/^item_/)
                @_manager.getItems()[id[5...]]

        _positionItem: (element, thisItem) ->
            # TODO could make use of binary search
            upper = undefined
            for el in $('.item')
                item = @_itemFromElement($(el))
                if item? and Item.comparator(thisItem, item) < 0
                    upper = item
                    break
            if upper?
                element.insertBefore($('#item_' + item.getID()))
            else
                element.appendTo($('#items'))

Create a html element that provides everything that is needed to display an
item.

        _createElement: (id) ->
            el = $('<table class="item">' + \
              '<tr>' + \
              '<td class="item-buttons-left">' + \
              '<button class="resolved" data-mini="true" ' + \
                    'data-icon="check" data-iconpos="notext" />' + \
              '</td>' + \
              '<td class="item-center">' + \
              '<div class="item-text"></div>' + \
              '</td>' + \
              '<td class="item-buttons-menu">' + \
              '<button class="acceptEdit" data-inline="true" data-mini="true" ' + \
                    'data-icon="check" data-iconpos="notext" />' + \
              '<button class="abortEdit" data-inline="true" data-mini="true" ' + \
                    'data-icon="delete" data-iconpos="notext" />' + \
              '<button class="move" data-inline="true" data-mini="true" ' + \
                    'data-icon="arrow-d" data-iconpos="notext" />' + \
              '<button class="edit" data-inline="true" data-mini="true" ' + \
                    'data-icon="edit" data-iconpos="notext" />' + \
              '</td>' + \
              '<td class="item-buttons-right">' + \
              '<button class="menu" data-inline="true" data-mini="true" ' + \
                    'data-icon="grid" data-iconpos="notext" />' + \
              '</td>' + \
              '</tr>' + \
              '</table>')
                .attr('id', 'item_' + id)
            $('button', el).button()
            $('.resolved', el).click(=> @_toggleItemResolution(id))
            $('.menu', el).click(=> @_toggleMenu(id))
            $('.move', el).bind('touchstart mousedown', (ev) => @_startDrag(id, ev))
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
                text = $('.item-text', '#item_' + id)
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
                @_hideMenu id
                $('.item-text', '#item_' + id)
                    .text(item.getText())
            @_replayIgnoredChanges()

Accept the edited text and save the item.

        _acceptEditItemClicked: (id) ->
            item = @_currentlyEditingItems[id]
            delete @_currentlyEditingItems[id]
            if item?
                @_showNonEditingState id
                @_hideMenu id
                text = $('.item-text', '#item_' + id).text()
                @_manager.saveItem item.setText(text)
            @_replayIgnoredChanges()

Set an item to the editing ui state.

        _showEditingButtonState: (id) ->
            $('.abortEdit, .acceptEdit', '#item_' + id)
                .closest('.ui-btn').show()
            $('.edit, .move', '#item_' + id)
                .closest('.ui-btn').hide()

Set the item back to the normal state.

        _showNonEditingState: (id) ->
            $('.item-text', '#item_' + id)
                .attr('contenteditable', 'false')
                .blur()
            $('.abortEdit, .acceptEdit', '#item_' + id)
                .closest('.ui-btn').hide()
            $('.edit, .move', '#item_' + id)
                .closest('.ui-btn').show()

Hide or show the menu.

        _toggleMenu: (id) ->
            $('.item-buttons-menu', '#item_' + id).toggle()

        _hideMenu: (id) ->
            $('.item-buttons-menu', '#item_' + id).hide()

Called when the user marks an item as resolved or not resolved. To just toggle
the item that is currently in the manager is a bit risky but the user will get
immediate feedback.

        _toggleItemResolution: (id) ->
            item = @_manager.getItems()[id]
            if item?
                @_manager.saveItem item.setResolved(not item.isResolved())

The functions handling drag and drop of items in the list.

        _startDrag: (id, event) ->
            return if @_currentlyDraggingItem?
            event.preventDefault()
            @_currentlyDraggingItem = @_manager.getItems()[id]

            pos = if event.originalEvent?.touches? then event.originalEvent.touches[0] else event
            @_dragCurrent = @_dragStart = [pos.pageX, pos.pageY]
            $('#item_' + id).css(
                zIndex: '13'
                position: 'relative'
                top: '0px'
                left: '0px')

        _moveDrag: (event) ->
            return unless @_currentlyDraggingItem?
            event.preventDefault()
            pos = if event.originalEvent?.touches? then event.originalEvent.touches[0] else event
            @_dragCurrent = [pos.pageX, pos.pageY]
            el = $('#item_' + @_currentlyDraggingItem.getID())

            move = Math.round((@_dragCurrent[1] - @_dragStart[1]) / @_itemHeight)
            @_repositionOtherItems(move)

            el[0].style.left = '0px'
            el[0].style.top = (@_dragCurrent[1] - @_dragStart[1]) + 'px'

Visually reposition the other items to reflect a relative move of the currently
dragging item by `move`.

        _repositionOtherItems: (move) ->
            return unless @_currentlyDraggingItem?

            el = $('#item_' + @_currentlyDraggingItem.getID())
            el.siblings(':visible').css(
                position: ''
                top: '')
            if move > 0
                el.nextAll(":visible:lt(#{move})").css(
                    position: 'relative'
                    top: (-@_itemHeight))
            if move < 0
                el.prevAll(":visible:lt(#{-move})").css(
                    position: 'relative'
                    top: @_itemHeight)

Reposition the currently dragging item by moving it in the DOM.

        _repositionItem: () ->
            return unless @_currentlyDraggingItem?

            el = $('#item_' + @_currentlyDraggingItem.getID())
            el.nextAll(':visible').css(
                position: '',
                top: '')
            move = Math.round((@_dragCurrent[1] - @_dragStart[1]) / @_itemHeight)
            return if move == 0

            siblingIndex = 0
            sibling = el
            while Math.abs(siblingIndex) < Math.abs(move)
                tentativeSibling = if move > 0
                        sibling.nextAll(':visible:first')
                    else
                        sibling.prevAll(':visible:first')
                break if tentativeSibling.length == 0
                sibling = tentativeSibling
                siblingIndex += if move > 0 then 1 else -1
            if siblingIndex > 0 then el.insertAfter(sibling)
            if siblingIndex < 0 then el.insertBefore(sibling)
            @_dragStart[1] += @_itemHeight * siblingIndex
            el[0].style.left = '0px'
            el[0].style.top = (@_dragCurrent[1] - @_dragStart[1]) + 'px'

        _endDrag: (event) ->
            item = @_currentlyDraggingItem
            return unless item?
            event.preventDefault()
            @_repositionOtherItems(0)
            @_repositionItem()
            @_currentlyDraggingItem = undefined
            el = $('#item_' + item.getID()).css(
                position: ''
                top: ''
                left: '')
            lower = @_itemFromElement(el.prev())?.getPosition()
            upper = @_itemFromElement(el.next())?.getPosition()
            pos =
                if lower? and upper?
                    (lower + upper) / 2.0
                else if lower?
                    lower + 1
                else if upper?
                    upper - 1
                else
                    0
            @_manager.saveItem(item.setPosition(pos))
            .then(=> @_hideMenu item.getID())
            # the update callback will hopefully re-position the element
            @_replayIgnoredChanges()


        _replayIgnoredChanges: ->
            queue = @_itemChangeQueue
            @_itemChangeQueue = []
            items = @_manager.getItems()
            @_onItemChanged(items[id]) for id in queue
            null

Export the Interface
--------------------
    (exports ? this).UserInterface = UserInterface
