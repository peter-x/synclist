Settings
========

User interface class to administer all settings, mostly to configure storage
backends. Provides observer mechanism where each observer is guaranteed to
receive at least one change notification. The arguments to the callback is a
list of backends with type, location (url), username, password and encryption
password.


    class Settings
        constructor: (@_database) ->
            @_storages = []
            $('#addStorage').click(() => @_populateSettingsForStorageDialog(-1))
            $('#apply-1').click(() => @_applyStorageSettings())
            $('#delete-1').click(() => @_deleteStorage())
            $('#settingsForStorage #type-1').change  ->
                s = $('#settingsForStorage')
                type = $('#type-1', s).val()
                $('.flexible-setting', s).hide()
                $('.setting-webdav', s).show() if type == 'WebDAV'
                $('.setting-remotestorage', s).show() if type == 'RemoteStorage'
                true
            @_database.observe (item) =>
                @_settingsChanged() if item == "settings"
            @_settingsChanged()

The following function will be extended by `Observer`.

        observe: (callback) ->
            callback(@_storages)

Private Methods
---------------

For each change in the database, recreate the UI.

        _settingsChanged: () ->
            @_database.load('settings')
                .then((data) =>
                    try
                        @_storages = JSON.parse data
                    catch error
                        @_storages = []
                    @_callObservers(@_storages)
                    @_updateUI())

        _updateUI: () ->
            list = $('#storagelist')
            list.empty()
            for storage, index in @_storages
                do (storage, index) =>
                    $('<li></li>').append(
                        $('<a href="#" ' +
                          'data-rel="dialog" data-role="button"></a>')
                        .text(storage.location)
                        .button()
                        .click(() =>
                            @_populateSettingsForStorageDialog(index)
                            $.mobile.changePage('#settingsForStorage')))
                    .appendTo(list)
            try
                list.listview()
            catch error

        _populateSettingsForStorageDialog: (index) ->
            s = $('#settingsForStorage')
            data = @_storages[index] ? {}
            type = data.type ? 'RemoteStorage'
            $('input', s).val('')
            $('#storage-index-1', s).val(index)
            if index == -1
                $('#delete-1', s).button().closest('.ui-btn').hide()
            else
                $('#delete-1', s).button().closest('.ui-btn').show()
            $('#type-1', s).val(type)
            $('#encpassword-1').val(data.encpassword ? '')
            switch type
                when "RemoteStorage"
                    $('#remotestorage-address', s).val(data.location ? '')
                when "WebDAV"
                    $('#webdav-url', s).val(data.location ? '')
                    $('#webdav-username', s).val(data.username ? '')
                    $('#webdav-password').val(data.password ? '')
            $('#type-1', s).change()

        _applyStorageSettings: ->
            index = +$('#storage-index-1').val()
            s = $('#settingsForStorage')
            data =
                type: $('#type-1', s).val()
                encpassword: $('#encpassword-1', s).val()
            if data.type == 'WebDAV'
                data.location = $('#webdav-url').val()
                data.username = $('#webdav-username').val()
                data.password = $('#webdav-password').val()
            else if data.type == 'RemoteStorage'
                data.location =  $('#remotestorage-address', s).val()

            @_database.load('settings')
                .always((settings) =>
                    try
                        settings = JSON.parse settings
                    catch error
                        settings = []
                    if index == '' or index < 0 then index = settings.length
                    settings[index] = data
                    @_database.save('settings', JSON.stringify settings)
                        .then(() => $('#settingsForStorage').dialog('close')))

        _deleteStorage: ->
            index = +$('#storage-index-1').val()
            return if index == '' or index < 0
            @_database.load('settings')
                .then((settings) =>
                    try
                        settings = JSON.parse settings
                    catch error
                        return
                    return if index < 0 or index >= settings.length
                    if confirm("Really delete " + settings[index].location + "?") != true
                        return
                        settings = []
                    settings.splice(index, 1)
                    @_database.save('settings', JSON.stringify settings)
                        .then(() => $('#settingsForStorage').dialog('close')))


    Observer(Settings)

Export the Interface
--------------------
    (exports ? this).Settings = Settings
