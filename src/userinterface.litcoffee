User Interface
==============

The UserInterface uses jquerymobile to style its html elements, is a change
observer of the manager and actually changes the items on the user's request.
Apart from the constructor, it has no public methods.

    class UserInterface
        constructor: (@_manager, @_syncService) ->
            @_currentlyEditingItems = {}
            @_currentlyDraggingItem = undefined
            @_currentlyDraggingElement = undefined
            @_dragStart = [0, 0]
            @_dragCurrent = [0, 0]
            @_dragLastMoveDiff = 0
            @_showResolved = false
            @_itemHeight = 48

            @_currentCategory = ''

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
            @_setCategory('')

Private Methods
---------------

Find all relevant html elements and register callbacks.

        _initializeUI: () ->
            $(document).bind('touchmove mousemove', (event) => @_moveDrag(event))
            $(document).bind('touchend touchcancel mouseup', (ev) => @_endDrag(ev))
            $('#showResolved').click () =>
                @_showResolved = not @_showResolved
                $('#showResolved').button({theme: if @_showResolved then 'b' else 'c'})
                @_showHideItems()

            newItem = @_createElementMarkup('newItem')
                .appendTo('#items')
            $('.item-text', newItem)
                .text('New item')
            newItemEditAbort = (ev) =>
                @_showNonEditingState '#newItem'
                $('.item-buttons-menu', '#newItem').hide()
                @_endTextEditing($('.item-text', newItem), 'New item')
                $('.item-text').removeClass('editing')
            newItemEditAccept = () =>
                text = $('.item-text', '#newItem').text()
                @_showNonEditingState '#newItem'
                $('.item-buttons-menu', '#newItem').hide()
                @_endTextEditing($('.item-text', '#newItem'), 'New item')
                $('.item-text').removeClass('editing')

                firstItem = @_itemFromElement($('.item:eq(1)')[0])
                pos = if firstItem? then firstItem.getPosition() - 1 else 0
                @_manager.saveItem Item.createNew(text,
                                                  @_currentCategory,
                                                  pos)
            $('.item-center', newItem)
                .click () =>
                    @_showEditingButtonState '#newItem'
                    $('.item-buttons-menu', '#newItem').show()
                    $('.item-text', '#newItem')
                        .text('')
                        .addClass('editing')
                    @_startTextEditing($('.item-text', newItem),
                        newItemEditAccept, newItemEditAbort)
            $('.abortEdit', newItem).click (ev) =>
                ev.preventDefault()
                newItemEditAbort()
            $('.acceptEdit', newItem).click (ev) =>
                ev.preventDefault()
                newItemEditAccept()
            $('#openCategories').click () =>
                @_showCategoryChooser().pipe(
                        (category) => @_setCategory(category),
                        () -> console.log('dialog rejected'))

            $('#syncState').click () =>
                @_syncService.fullSync()

Shows the category chooser dialog, returns promise.

        _showCategoryChooser: (titleText = 'Categories') ->
            deferred = $.Deferred()
            $('#categoriesListHeader').text(titleText)
            $('#categoriesList')
                .empty()
                .append('<li data-icon="plus"><a href="#" id="newCategory">New Category</a></li>')
                .append('<li><a href="#" id="defaultCategory">Default Category</a></li>')

            categories = @_manager.getCategories()
            categories.sort()
            for category in categories
                continue if category == ''
                $('#categoriesList').append(
                    $('<li/>').append($('<a href="#"/>').text(category)))
            $('#categoriesList').listview('refresh')
            $('#categoriesList li a').click (ev) =>
                cat = ''
                if ev.target.id is 'newCategory'
                    cat = window.prompt("Text")
                    return unless cat?
                else if ev.target.id is 'defaultCategory'
                    cat = ''
                else
                    cat = ev.target.text
                deferred.resolve(cat)
                window.setTimeout((() -> $('#categoriesPanel').popup('close')),
                                  1)
            window.setTimeout((() -> $('#categoriesPanel').popup('open')),
                              1)
            $('#categoriesPanel').on('popupafterclose', () =>
                deferred.reject() unless deferred.state() == 'resolved')
            deferred.promise()


Updates the visibility of all items.

        _showHideItems: () ->
            @_showHideItem(item, $('#item_' + id)) for id, item of @_manager.getItems()

        _isItemVisible: (item) ->
            category = @_currentCategory
            (@_showResolved or not item.isResolved()) and \
                      item.getCategory() == category

        _showHideItem: (item, element) ->
            if @_isItemVisible(item)
                element.addClass('visibleItem')
            else
                element.removeClass('visibleItem')

        _setCategory: (category) ->
            @_currentCategory = category
            category = 'Default Category' if category == ''
            $('#currentCategory').text(category)
            @_showHideItems()

Apply changes found in the database. This also applies changes made by the user
after they went through the database.

        _onItemChanged: (item) ->
            id = item.getID()
            if @_currentlyEditingItems[id]? or @_currentlyDraggingItem?
                @_itemChangeQueue.push(id)
                return
            element = $('#item_' + id)
            isInserted = element.length > 0
            element = @_createElement(id) if not isInserted
            @_showHideItem(item, element)
            SimpleButton.setHilight($('.resolved', element), item.isResolved())
            $('.item-text', element).text(item.getText())
            @_positionItem(element, item, isInserted)
            item

        _itemFromElement: (element) ->
            id = element?.id
            if id? and id.match(/^item_/)
                @_manager.getItems()[id[5...]]

Returns the first element `x` from `list` where `comparator(x)` is true. Assumes
that all elements in `list` where `comparator` returns false precede those
where it returns true.

        _binarySearch: (list, comparator) ->
            begin = 0
            end = list.length
            while begin < end
                mid = Math.floor((end + begin) / 2)
                if not comparator(list[mid])
                    begin = mid + 1
                else
                    end = mid
            list[begin] if begin < list.length

TODO: This is a bug: If two items change before we can reposition them, the list
will not be sorted and we cannot use this pseudo-insertion-sort.

        _positionItem: (element, thisItem, isInserted) ->
            items = $('.item').not('#newItem')
            if isInserted
                items = items.not('#' + element.id)
            upper = @_binarySearch(items, (el) =>
                item = @_itemFromElement(el)
                item? and Item.comparator(thisItem, item) < 0)
            if upper?
                element.insertBefore($(upper))
            else if not isInserted
                element.appendTo('#items')

Create a html element that provides everything that is needed to display an
item.

        _createElementMarkup: (elementId) ->
            $('<table class="item">' + \
              '<tr>' + \
              '<td class="item-buttons-left">' + \
              SimpleButton.getMarkup('check', 'resolved') + \
              '</td>' + \
              '<td class="item-center">' + \
              '<div class="item-text"></div>' + \
              '</td>' + \
              '<td class="item-buttons-menu">' + \
              SimpleButton.getMarkup('check', 'acceptEdit') + \
              SimpleButton.getMarkup('delete', 'abortEdit') + \
              SimpleButton.getMarkup('arrow-u', 'move') + \
              SimpleButton.getMarkup('edit', 'edit') + \
              SimpleButton.getMarkup('forward', 'changeCategory') + \
              '</td>' + \
              '<td class="item-buttons-right">' + \
              SimpleButton.getMarkup('grid', 'menu') + \
              '</td>' + \
              '</tr>' + \
              '</table>')
                .attr('id', elementId)

        _createElement: (id) ->
            el = @_createElementMarkup('item_' + id)
            $('.resolved', el).click(=> @_toggleItemResolution(id))
            $('.menu', el).click(=> @_toggleMenu(id))
            $('.move', el).bind('touchstart mousedown', (ev) => @_startDrag(id, ev))
            $('.edit', el).click(=> @_editItemClicked(id))
            $('.abortEdit', el)
                .click(=> @_abortEditItem(id))
                .hide()
            $('.acceptEdit', el)
                .click(=> @_acceptEditItem(id))
                .hide()
            $('.changeCategory', el)
                .click(=> @_changeItemCategoryClicked(id))
            el

Start editing the item. It is important to first retrieve the item so that
concurrent changes are not lost but merged. After that, show the accept and
abort buttons and position the cursor at the end of the text.

        _editItemClicked: (id) ->
            return if @_currentlyEditingItems[id]?
            item = @_manager.getItems()[id]
            if item?
                @_currentlyEditingItems[id] = item
                @_showEditingButtonState '#item_' + id
                @_startTextEditing(
                    $('.item-text', '#item_' + id),
                    () => @_acceptEditItem(id),
                    () => @_abortEditItem(id))

        _startTextEditing: (textElement, onReturn = undefined,
                                         onEscape = undefined) ->
            textElement.attr('contenteditable', 'true')
            range = document.createRange()
            range.selectNode(textElement[0].childNodes[0])
            range.collapse(false)
            sel = window.getSelection()
            sel.removeAllRanges()
            sel.addRange(range)
            if onReturn?
                textElement.keypress((ev) =>
                    if ev.which == 13
                        ev.preventDefault()
                        onReturn())
            if onEscape?
                textElement.keyup((ev) =>
                    if ev.which == 27
                        ev.preventDefault()
                        onEscape())
            textElement.focus()

        _endTextEditing: (textElement, text = '') ->
            textElement
                .text(text)
                .attr('contenteditable', 'false')
                .unbind('keypress')
                .unbind('keyup')
                .blur()

Abort editing the item, restore the previous user interface.

        _abortEditItem: (id) ->
            item = @_currentlyEditingItems[id]
            delete @_currentlyEditingItems[id]
            if item?
                @_endTextEditing($('.item-text', '#item_' + id),
                                 item.getText())
                @_showNonEditingState '#item_' + id
                @_hideMenu id

            @_replayIgnoredChanges()

Accept the edited text and save the item.

        _acceptEditItem: (id) ->
            item = @_currentlyEditingItems[id]
            delete @_currentlyEditingItems[id]
            if item?
                text = $('.item-text', '#item_' + id).text()
                @_endTextEditing($('.item-text', '#item_' + id),
                                 text)
                @_showNonEditingState '#item_' + id
                @_hideMenu id
                @_manager.saveItem item.setText(text)
            @_replayIgnoredChanges()

Open a dialog box where an item's category can be changed.

        _changeItemCategoryClicked: (id) ->
            item = @_manager.getItems()[id]
            if item?
                @_hideMenu id
                @_showCategoryChooser('Move To')
                    .pipe((category) =>
                        @_manager.saveItem item.setCategory(category))

Set an item to the editing ui state.

        _showEditingButtonState: (elementId) ->
            $('.abortEdit, .acceptEdit', elementId).show()
            $('.edit, .move, .changeCategory', elementId).hide()

Set the item back to the normal state.

        _showNonEditingState: (elementId) ->
            $('.abortEdit, .acceptEdit', elementId).hide()
            $('.edit, .move, .changeCategory', elementId).show()

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
            @_currentlyDraggingElement = $('#item_' + id)

            pos = if event.originalEvent?.touches? then event.originalEvent.touches[0] else event
            @_dragCurrent = @_dragStart = [pos.pageX, pos.pageY]
            @_currentlyDraggingElement.css(
                zIndex: '13'
                position: 'relative'
                top: '0px'
                left: '0px')

        _moveDrag: (event) ->
            return unless @_currentlyDraggingItem?
            event.preventDefault()
            pos = if event.originalEvent?.touches? then event.originalEvent.touches[0] else event
            @_dragCurrent = [pos.pageX, pos.pageY]
            el = @_currentlyDraggingElement

            move = Math.round((@_dragCurrent[1] - @_dragStart[1]) / @_itemHeight)

            el[0].style.top = (@_dragCurrent[1] - @_dragStart[1]) + 'px'

            return unless @_dragLastMoveDiff != move

            if @_dragLastMoveDiff > 0
                el.nextAll(".visibleItem:lt(#{@_dragLastMoveDiff})").css(
                    top: '0px')
            if @_dragLastMoveDiff < 0
                el.prevAll(".visibleItem:lt(#{-@_dragLastMoveDiff})").css(
                    top: '0px')
            if move > 0
                el.nextAll(".visibleItem:lt(#{move})").css(
                    position: 'relative'
                    top: (-@_itemHeight) + 'px')
            if move < 0
                el.prevAll(".visibleItem:lt(#{-move})").css(
                    position: 'relative'
                    top: @_itemHeight + 'px')
            @_dragLastMoveDiff = move

Reposition the currently dragging item by moving it in the DOM.

        _repositionItem: () ->
            return false unless @_currentlyDraggingItem?

            el = @_currentlyDraggingElement
            $('.item').css(
                position: '',
                top: '')
            move = Math.round((@_dragCurrent[1] - @_dragStart[1]) / @_itemHeight)
            return false if move == 0

            siblingIndex = 0
            sibling = el
            while Math.abs(siblingIndex) < Math.abs(move)
                tentativeSibling = if move > 0
                        sibling.nextAll('.visibleItem:first')
                    else
                        sibling.prevAll('.visibleItem:first')
                break if tentativeSibling.length == 0
                sibling = tentativeSibling
                siblingIndex += if move > 0 then 1 else -1
            if siblingIndex > 0 then el.insertAfter(sibling)
            if siblingIndex < 0 then el.insertBefore(sibling)
            @_dragStart[1] += @_itemHeight * siblingIndex
            el[0].style.left = '0px'
            el[0].style.top = (@_dragCurrent[1] - @_dragStart[1]) + 'px'
            siblingIndex != 0

        _endDrag: (event) ->
            item = @_currentlyDraggingItem
            return unless item?
            event.preventDefault()
            movedSomething = @_repositionItem()
            @_currentlyDraggingItem = undefined
            el = @_currentlyDraggingElement
            @_currentlyDraggingElement = undefined
            if movedSomething
                lower = @_itemFromElement(el.prev()[0])?.getPosition()
                upper = @_itemFromElement(el.next()[0])?.getPosition()
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


Helper Classes
--------------

The `SimpleButton` is a high-performance replacement for jQueryMobile's button
and uses its css classes.

    SimpleButton =
        hilightClass: (hilight) ->
            if hilight then 'ui-btn-up-b' else 'ui-btn-up-c'

        getMarkup: (icon, cssClass = '', hilight = false) ->
            cssClass += ' ' if cssClass != ''
            cssClass += SimpleButton.hilightClass(hilight) + ' '
            "<div class=\"#{cssClass}ui-btn ui-shadow ui-mini " + \
                         "ui-btn-corner-all ui-btn-inline " + \
                         "ui-btn-icon-notext\" aria-disabled=\"false\">" + \
                "<span class=\"ui-btn-inner\">" + \
                    "<span class=\"ui-icon ui-icon-#{icon} ui-icon-shadow\">" + \
                        "&nbsp;</span></span></div>"

        setHilight: (element, hilight = false) ->
            $(element)
                .removeClass(@hilightClass(not hilight))
                .addClass(@hilightClass(hilight))

Export the Interface
--------------------
    (exports ? this).UserInterface = UserInterface
