Sync Service
============

A very simple service that makes sure that each object that lives in one
database is copied to all other databases. Merging conflicting changes is
handeled in the `Manager`.

*TODO*: cleanup the observers in the destructors, or even better:
write some generic change notificaton observer mechanism that can be used by all
classes

    class SyncService

        constructor: (@_settings, @_database) ->
            @_synchronizers = []
            @_settings.observe (remoteSettings) =>
                if console?
                    console.log "Syncservice: Change in settings detected"
                s.destroy() for s in @_synchronizers

                @_synchronizers = []
                for dbSetting in remoteSettings
                    db = @_settingToDb dbSetting
                    if db
                        @_synchronizers.push new Synchronizer(@_database, db)

        _settingToDb: (setting) ->
            if setting.type == 'LocalStorage'
                dbClass = LocalStorageBackend
                options = {context: setting.location}
                encpassword = setting.encpassword
                new Database(dbClass, options, encpassword)
            else if setting.type == 'WebDAV'
                dbClass = WebDavBackend
                options = {url: setting.location, \
                           username: setting.username, \
                           password: setting.password}
                encpassword = setting.encpassword
                new Database(dbClass, options, encpassword)
            else
                null

Synchronizer Helper
-------------------

This class handles the synchronization between the local database and a single
other database, in both directions. Upon construction, it tries to synchronize
everything and then reacts on changes in both databases.

    class Synchronizer
        constructor: (@_sourceDB, @_targetDB) ->
            @_changesToIgnore = {}
            @_active = true # workaround until we can unregister observers
            @_sourceDB.observe (filename) =>
                if @_changesToIgnore[filename]?
                    delete @_changesToIgnore[filename]
                else
                    @_changesToIgnore[filename] = 1
                    @_transferTo filename
            @_targetDB.observe (filename) =>
                if @_changesToIgnore[filename]?
                    delete @_changesToIgnore[filename]
                else
                    @_changesToIgnore[filename] = 1
                    @_transferFrom filename
            @_fullSync()

        destroy: () ->
            @_active = false

        _fullSync: () ->
            return unless @_active
            @_sourceDB.listObjects()
            .then (sourceList) =>
                return unless @_active
                @_targetDB.listObjects()
                .then (targetList) =>
                    return unless @_active
                    toTransferTo = Utilities.sortedArrayDifference(sourceList,
                                                                   targetList)
                    @_transferTo(x) for x in toTransferTo
                    toTransferFrom = Utilities.sortedArrayDifference(targetList,
                                                                     sourceList)
                    @_transferFrom(x) for x in toTransferFrom

        _transferTo: (filename) ->
            @_transfer(filename, @_sourceDB, @_targetDB)

        _transferFrom: (filename) ->
            @_transfer(filename, @_targetDB, @_sourceDB)

        _transfer: (filename, db1, db2) ->
            return unless @_active and filename.match /^item_/
            if console?
                console.log "Syncservice: Transferring " + filename + "."
            db1.load(filename)
            .then (data) =>
                return unless data and @_active
                db2.save(filename, data)


Export the Interface
--------------------

    (exports ? this).SyncService = SyncService
