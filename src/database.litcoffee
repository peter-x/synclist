Database Interface
======================

Later, this interface can be used to access both local and remote database. For
now, we only support LocalStorage.

    Database =
        save: (filename, data) ->
            data = Crypto.encrypt(data, 'simple constant password')
            window.localStorage[filename] = data
        load: (filename) ->
            data = window.localStorage[filename]
            Crypto.decrypt(data, 'simple constant password')

Export the Interface
--------------------
    (exports ? this).Database = Database
