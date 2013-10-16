describe 'Item', ->
    it 'should not create an item from corrupt JSON string', ->
        expect(Item.createFromJSON('1-abcdef01234', '{')).toBeNull()
    it 'should create a new item', ->
        text = 'Example Text'
        category = 'Example Category'
        i = Item.createNew text, category
        expect(i.getID().length).toBeGreaterThan(0)
        expect(i.getCreated()).toBeGreaterThan(0)
        expect(i.getResolved()).toEqual(0)
        expect(i.getText()).toEqual(text)
        expect(i.getCategory()).toEqual(category)
