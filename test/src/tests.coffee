describe 'Item', ->
    it 'should not create an item from corrupt JSON string', ->
        expect(Item.createFromJSON('1-abcdef01234', '{')).toBeNull()
    it 'should create an item from correct JSON string', ->
        data = '{"revisions":[],"creation":1382207794.2,"resolution":0,' +
               '"modification":1382207794,"category":"Some category",' +
               '"text":"Some text","position":1.2}'
        i = Item.createFromJSON('someid-1-abcdef01234', data)
        expect(i.getID()).toEqual('someid')
        expect(i.revision).toMatch(/^1-abcdef01234$/)
        expect(i.getCreated()).toEqual(1382207794.2)
        expect(i.isResolved()).toEqual(false)
        expect(i.getCategory()).toEqual('Some category')
        expect(i.getText()).toEqual('Some text')
        expect(i.getPosition()).toEqual(1.2)
    it 'should create a new item', ->
        text = 'Example Text'
        category = 'Example Category'
        i = Item.createNew text, category
        expect(i.getID().length).toBeGreaterThan(0)
        expect(i.getCreated()).toBeGreaterThan(0)
        expect(i.getResolved()).toEqual(0)
        expect(i.getText()).toEqual(text)
        expect(i.getCategory()).toEqual(category)
        expect(i.revision).toMatch(/^1-/)
    it 'should increase revision numbers on change and store revisions', ->
        i = Item.createNew 'text', 'category'
        expect(i.revision).toMatch(/^1-/)
        firstRevision = i.revision
        i = i.setPosition(10)
        expect(i.getPosition()).toEqual(10)
        expect(i.revision).toMatch(/^2-/)
        secondRevision = i.revision
        i = i.setText('text2')
        expect(i.getText()).toEqual('text2')
        expect(i.revision).toMatch(/^3-/)
        thirdRevision = i.revision
        expect(firstRevision[2..]).not.toEqual(secondRevision[2..])
        expect(firstRevision[2..]).not.toEqual(thirdRevision[2..])
        expect(secondRevision[2..]).not.toEqual(thirdRevision[2..])
        expect(i.revisions).toEqual([firstRevision, secondRevision])
    it 'should encode and decode without changes', ->
        text = 'Some text'
        category = 'Some category'
        position = 1.2
        resolution = 23
        i = Item.createNew(text, category)
        i = i.setPosition position
        i = i.setResolved resolution

        filename = i.id + '-' + i.revision
        j = Item.createFromJSON(filename, i.jsonEncode())
        expect(j.getID()).toEqual(i.getID())
        expect(j.getCreated()).toEqual(i.getCreated())
        expect(j.getResolved()).toEqual(i.getResolved())
        expect(j.getText()).toEqual(i.getText())
        expect(j.getCategory()).toEqual(i.getCategory())
        expect(j.revision).toEqual(i.revision)
        expect(j.revisions).toEqual(i.revisions)
    it 'should correctly compute the latest common ancestor', ->
        id = 'abc'
        itemA = new Item(id, '4-d', ['1-a', '2-b', '3-c'])
        itemB = new Item(id, '4-d2', ['1-a', '2-b', '3-F'])
        itemC = new Item(id, '5-d3', ['1-a', '2-b', '3-c', '4-d'])
        itemD = new Item(id, '3-F', ['1-a', '2-b'])
        itemE = new Item(id, '3-c', ['1-a', '2-b'])
        itemF = new Item(id, '5-d3', ['1-a', '2-X', '3-Y', '4-Z'])
        itemG = new Item(id, '2-d3', ['1-X'])
        expect(itemA.getLatestCommonAncestor(itemA)).toEqual('4-d')
        expect(itemA.getLatestCommonAncestor(itemB)).toEqual('2-b')
        expect(itemA.getLatestCommonAncestor(itemC)).toEqual('4-d')
        expect(itemA.getLatestCommonAncestor(itemD)).toEqual('2-b')
        expect(itemA.getLatestCommonAncestor(itemE)).toEqual('3-c')
        expect(itemA.getLatestCommonAncestor(itemF)).toEqual('1-a')
        expect(itemA.getLatestCommonAncestor(itemG)).toEqual(null)
    it 'should correctly merge in case of no conflicts', ->
        id = 'abc'
        item = Item.createNew('text', 'category')
        itemA = item.setText('text2')
        itemB = item.setCategory('category2')
        merged = itemA.mergeWith(itemB, item)
        expect(merged.getText()).toEqual('text2')
        expect(merged.getCategory()).toEqual('category2')
        expect(merged.getResolved()).toBeFalsy()
        revs = merged.getRevisionsIncludingSelf()
        expect(revs).toContain(item.getRevision())
        expect(revs).toContain(itemA.getRevision())
        expect(revs).toContain(itemB.getRevision())
        expect(revs).toContain(merged.getRevision())
        expect(revs.length).toEqual(4)

        itemC = item.setResolved()
        merged = itemC.mergeWith(itemA, item)
        expect(merged.getText()).toEqual('text2')
        expect(merged.getCategory()).toEqual('category')
        expect(merged.getResolved()).toBeTruthy()
        expect(item.getResolved()).toBeFalsy()
        expect(itemA.getResolved()).toBeFalsy()

        itemC2 = merged.setText('abc')
        expect(itemC2.getResolved()).toEqual(merged.getResolved())
        itemC3 = merged.setCategory('def')
        merged = itemC2.mergeWith(itemC3, merged)
        expect(merged.getResolved()).toEqual(itemC2.getResolved())

        itemD = item.setPosition(20)
        merged = itemA.mergeWith(itemD, item)
        expect(merged.getPosition()).toEqual(20)
        itemE = merged.setPosition(21)
        merged2 = itemE.mergeWith(itemD, itemD)
        expect(merged2.getPosition()).toEqual(21)

    it 'should correctly merge in case of conflicts', ->
        item = Item.createNew('text', 'category')
        itemA = item.setResolved()
        expect(itemA.getResolved()).toBeGreaterThan(0)

        itemB = item.setResolved()
        # hack in the resolved value, this invalidates the revision
        # but should not be a problem
        itemB.resolved = itemA.resolved + 10
        merged = itemB.mergeWith(itemA, item)
        expect(merged.getResolved()).toEqual(itemA.getResolved())

        itemA = item.setText('a smallertext').setCategory('a smallercategory')
        itemB = item.setText('b largertext').setCategory('b largercategory')
        merged = itemB.mergeWith(itemA, item)
        expect(merged.getText()).toEqual('a smallertext, b largertext')
        expect(merged.getCategory()).toEqual('a smallercategory, b largercategory')

        itemA = item.setPosition(5)
        itemB = item.setPosition(7)
        merged = itemA.mergeWith(itemB, item)
        expect(merged.getPosition()).toEqual(5)

describe 'Database with LocalStorageBackend', ->
    database = new Database(LocalStorageBackend, {context: 'synclist_test'})
    failure = jasmine.createSpy('failure')
    success = jasmine.createSpy('success')
    beforeEach ->
        success.callCount = 0
        failure.callCount = 0
        LocalStorageBackend.clearContext('synclist_test')
        database.clearObservers()
    it 'should list objects', ->
        database.listObjects()
        .fail(failure)
        .then (objects) ->
            expect(objects).toEqual([])
            success()

        database.save('firstitem', 'data')
        .fail(failure)
        database.listObjects()
        .fail(failure)
        .then (objects) ->
            expect(objects).toEqual(['firstitem'])
            success()

        database.save('seconditem', 'data')
        .fail(failure)
        database.listObjects()
        .fail(failure)
        .then (objects) ->
            objects.sort()
            expect(objects).toEqual(['firstitem', 'seconditem'])
            success()

        expect(success.callCount).toEqual(3)
        expect(failure).not.toHaveBeenCalled()
    it 'should load the same data it saved', ->
        data = 'abcdef'
        database.save('somefile', data)
        .fail(failure)
        database.load('somefile')
        .fail(failure)
        .then (returnedData) ->
            expect(returnedData).toEqual(data)
            success()
        expect(success.callCount).toEqual(1)
        expect(failure).not.toHaveBeenCalled()
    it 'should use the password', ->
        database2 = new Database(LocalStorageBackend, {context: 'synclist_test'}, \
                                 'otherpassword')
        data = 'asoeuoecug'
        database.save 'somefile2', data
        database2.load('somefile2')
        .fail -> expect(true).toBeFalsy()
        .then (returnedData) ->
            expect(true).toBeFalsy()
            expect(returnedData).not.toEqual(data)
    it 'should call change observers', ->
        callback = jasmine.createSpy 'onChange'
        database.onChange callback
        expect(callback).not.toHaveBeenCalled()
        database.save 'callbacktestfile', 'euotu'
        expect(callback).toHaveBeenCalledWith('callbacktestfile')
        database.save 'callbacktestfile2', 'euotu'
        expect(callback).toHaveBeenCalledWith('callbacktestfile2')

describe 'Utilities', ->
    it 'should convert empty arrays to empty sets', ->
        expect(Utilities.arrayToSet([])).toEqual({})
    it 'should convert arrays to sets', ->
        expect(Utilities.arrayToSet(['', '7', '4', '3']))
                .toEqual({'': 1, '7': 1, '4': 1, '3': 1})
        expect(Utilities.arrayToSet(['7', '4', '7', '3', '4']))
                .toEqual({'7': 1, '4': 1, '3': 1})
        expect(Utilities.arrayToSet(['a', '4', '7', '3', '4']))
                .toEqual({'a': 1, '7': 1, '4': 1, '3': 1})
    it 'should convert arrays to sets and back to arrays', ->
        array = ['1', 'a', '7', 'b']
        array.sort()
        expect(Utilities.setToArray(Utilities.arrayToSet(array))).toEqual(array)
    it 'should convert arrays to sets and back to arrays, removing duplicates', ->
        array = ['1', 'a', '7', 'b', '7']
        array.sort()
        expect(Utilities.setToArray(Utilities.arrayToSet(array))).not.toEqual(array)
    it 'should sort arrays and remove duplicates', ->
        array = ['1', '8', '1', '', '', '3']
        expect(Utilities.sortedArrayWithoutDuplicates(array))
                .toEqual(['', '1', '3', '8'])
    it 'should correctly compute the symmetric difference', ->
        array1 = [    'e', 'g', 'a', 'b']
        array2 = ['',      'b',      'g', '']
        expect(Utilities.symmetricSortedArrayDifference(array1, array2))
            .toEqual(['', 'a', 'e'])
        expect(Utilities.symmetricSortedArrayDifference([], ['a']))
            .toEqual(['a'])
        expect(Utilities.symmetricSortedArrayDifference(['a'], ['a', 'b']))
            .toEqual(['b'])

describe 'Manager',->
    database = new Database(LocalStorageBackend, {context: 'synclist_test'})
    manager = null
    failure = jasmine.createSpy('failure')
    success = jasmine.createSpy('success')
    beforeEach ->
        success.callCount = 0
        failure.callCount = 0
        LocalStorageBackend.clearContext('synclist_test')
        database.clearObservers()
        manager.clearObservers() if manager?
        manager = new Manager(database)
    it 'should save an item', ->
        manager.saveItem(Item.createNew 'testData')
        .fail(failure)
        .then ->
            items = (item for id, item of manager.getItems())
            expect(items.length).toEqual 1
            success()
        expect(success.callCount).toEqual(1)
        expect(failure).not.toHaveBeenCalled()
    it 'should save a new revision', ->
        item = Item.createNew 'testData'
        manager.saveItem(item)
        .fail(failure)
        .then () ->
            expect(id for id of manager.getItems()).toEqual([item.getID()])
            success()

        item2 = item.setCategory 'newCategory'
        manager.saveItem(item2)
        .fail(failure)
        .then(success)

        expect(id for id of manager.getItems()).toEqual([item.getID()])
        expect(manager.getItems()[item.getID()].getRevision())
            .toEqual(item2.getRevision())

        expect(success.callCount).toEqual(2)
        expect(failure).not.toHaveBeenCalled()
    it 'should merge conflicts', ->
        item = Item.createNew 'testData'
        manager.saveItem(item)
        .fail(failure)
        .then(success)

        id = item.getID()

        item2 = item.setCategory 'newCategory'
        manager.saveItem(item2)
        .fail(failure)
        .then(success)
        expect(manager.getItems()[id].getRevision()).toEqual(item2.getRevision())

        item3 = item.setText 'newText'
        manager.saveItem(item3)
        .fail(failure)
        .then(success)

        revision = manager.getItems()[id].getRevision()
        expect(revision).not.toEqual(item3.getRevision())
        expect(revision).not.toEqual(item2.getRevision())
        expect(revision).toMatch(/^3-/)

        expect(success.callCount).toEqual(3)
        expect(failure).not.toHaveBeenCalled()
    it 'should notify observers', ->
        callback = jasmine.createSpy 'onChange'
        manager.onChange(callback)
        expect(callback).not.toHaveBeenCalled()
        item = Item.createNew('testData')
        manager.saveItem item
        expect(callback).toHaveBeenCalledWith(item)
