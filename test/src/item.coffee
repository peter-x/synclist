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

describe 'LocalStorageDatabase', ->
    database = new LocalStorageDatabase('synclist_test')
    beforeEach ->
        database.clear()
    it 'should list objects', ->
        expect(database.listObjects()).toEqual([])
        database.save 'firstitem', 'data'
        expect(database.listObjects()).toEqual(['firstitem'])
        database.save 'seconditem', 'data'
        objects = database.listObjects()
        objects.sort()
        expect(objects).toEqual(['firstitem', 'seconditem'])
    it 'should load the same data it saved', ->
        data = 'abcdef'
        database.save 'somefile', data
        expect(database.load 'somefile').toEqual(data)
    it 'should use the password', ->
        database2 = new LocalStorageDatabase('synclist_test', 'otherpassword')
        data = 'asoeuoecug'
        database.save 'somefile2', data
        expect(database2.load 'somefile2').not.toEqual(data)
    it 'should call change observers', ->
        callbackdata = null
        database.onChange (data) -> callbackdata = data
        expect(callbackdata).toBeNull()
        database.save 'callbacktestfile', 'euotu'
        expect(callbackdata).toEqual('callbacktestfile')
        database.save 'callbacktestfile2', 'euotu'
        expect(callbackdata).toEqual('callbacktestfile2')
