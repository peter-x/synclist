describe 'Item', ->
    beforeEach ->
        Database.setContext('synclist_test')
        Database.clear()

    it 'should not create an item from corrupt JSON string', ->
        expect(Item.createFromJSON('1-abcdef01234', '{')).toBeNull()
    it 'should create an item from correct JSON string', ->
        data = '{"revisions":[],"creation":1382207794.2,"resolution":0,' +
               '"modification":1382207794,"category":"Some category",' +
               '"text":"Some text","position":1.2}'
        i = Item.createFromJSON('someid-1-abcdef01234', data)
        expect(i.getID()).toEqual('someid')
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
    it 'should increase revision numbers on change and store revisions', ->
        i = Item.createNew 'text', 'category'
        expect(i.revision).toMatch(/^1-/)
        firstRevision = i.revision
        i.setPosition(10)
        expect(i.revision).toMatch(/^2-/)
        secondRevision = i.revision
        i.setText('text2')
        expect(i.revision).toMatch(/^3-/)
        thirdRevision = i.revision
        expect(firstRevision[2..]).not.toEqual(secondRevision[2..])
        expect(firstRevision[2..]).not.toEqual(thirdRevision[2..])
        expect(secondRevision[2..]).not.toEqual(thirdRevision[2..])
        expect(i.revisions).toEqual([firstRevision, secondRevision])
    it 'should save itself to the storage', ->
        expect(Database.listObjects().length).toEqual(0)
        i = Item.createNew 'text', 'category'
        expect(Database.listObjects().length).toEqual(1)
        i.setCategory('new category')
        expect(Database.listObjects().length).toEqual(2)
    it 'should load items from storage without changes', ->
        text = 'Some text'
        category = 'Some category'
        position = 1.2
        resolution = 23
        i = Item.createNew(text, category)
        i.setPosition position
        i.setResolved resolution

        filename = i.id + '-' + i.revision
        j = Item.createFromJSON(filename, Database.load(filename))
        expect(j.getID()).toEqual(i.getID())
        expect(j.getCreated()).toEqual(i.getCreated())
        expect(j.getResolved()).toEqual(i.getResolved())
        expect(j.getText()).toEqual(i.getText())
        expect(j.getCategory()).toEqual(i.getCategory())
        expect(j.revision).toEqual(i.revision)
        expect(j.revisions).toEqual(i.revisions)
