// Generated by CoffeeScript 1.6.1
(function() {
  var Database, LocalStorageBackend, WebDavBackend;

  LocalStorageBackend = (function() {

    function LocalStorageBackend(_changeNotification, config) {
      var _this = this;
      this._changeNotification = _changeNotification;
      if (config == null) {
        config = {
          context: 'synclist'
        };
      }
      this._context = config.context;
      this._localStorage = window.localStorage;
      window.addEventListener('storage', function(ev) {
        if (_this._keyIsInContext(ev.key)) {
          return _this._changeNotification(_this._withoutContext(ev.key));
        }
      });
    }

    LocalStorageBackend.prototype.list = function() {
      var i, ls;
      ls = this._localStorage;
      return Utilities.deferredPromise((function() {
        var _i, _ref, _results;
        _results = [];
        for (i = _i = 0, _ref = ls.length; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
          if (this._keyIsInContext(ls.key(i))) {
            _results.push(this._withoutContext(ls.key(i)));
          }
        }
        return _results;
      }).call(this));
    };

    LocalStorageBackend.prototype.get = function(key) {
      return Utilities.deferredPromise(this._localStorage[this._context + '/' + key]);
    };

    LocalStorageBackend.prototype.put = function(key, data) {
      return Utilities.deferredPromise(this._localStorage[this._context + '/' + key] = data, this._changeNotification(key));
    };

    LocalStorageBackend.clearContext = function(context) {
      var i, item, itemsToDelete, ls, _i, _len, _results;
      ls = window.localStorage;
      itemsToDelete = (function() {
        var _i, _ref, _results;
        _results = [];
        for (i = _i = 0, _ref = ls.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
          if (ls.key(i).slice(0, +context.length + 1 || 9e9) === context + '/') {
            _results.push(ls.key(i));
          }
        }
        return _results;
      })();
      _results = [];
      for (_i = 0, _len = itemsToDelete.length; _i < _len; _i++) {
        item = itemsToDelete[_i];
        _results.push(ls.removeItem(item));
      }
      return _results;
    };

    LocalStorageBackend.prototype._keyIsInContext = function(name) {
      return (name != null) && name.slice(0, +this._context.length + 1 || 9e9) === this._context + '/';
    };

    LocalStorageBackend.prototype._withoutContext = function(name) {
      return name.slice(this._context.length + 1);
    };

    return LocalStorageBackend;

  })();

  WebDavBackend = (function() {

    function WebDavBackend(_changeNotification, config) {
      var authString;
      this._changeNotification = _changeNotification;
      this._url = config.url;
      if (this._url[this._url.length - 1] !== '/') {
        this._url += '/';
      }
      this._username = config.username;
      this._password = config.password;
      authString = 'Basic ' + Crypto.utf8ToBase64(this._username + ':' + this._password);
      this._authHeader = {
        Authorization: authString
      };
    }

    WebDavBackend.prototype.list = function() {
      var ajaxOptions, requestHost, requestPath, _ref;
      _ref = this._url.match(/^(https?:\/\/[^\/]*)(\/.*)/).slice(1), requestHost = _ref[0], requestPath = _ref[1];
      ajaxOptions = {
        url: this._url,
        type: 'PROPFIND',
        contentType: 'application/xml',
        headers: {
          Depth: '1',
          Authorization: this._authHeader['Authorization']
        },
        data: '<?xml version="1.0" encoding="utf-8" ?>' + '<propfind xmlns="DAV:"><prop></prop></propfind>'
      };
      return jQuery.ajax(ajaxOptions).pipe(function(data) {
        var entries;
        entries = [];
        jQuery('response', data).each(function(i, el) {
          var elPath;
          elPath = jQuery('href', el).text().replace(/^https?:\/\/[^\/]*/, '');
          if (elPath.slice(0, +(requestPath.length - 1) + 1 || 9e9) === requestPath) {
            el = elPath.slice(requestPath.length);
            if (el !== '' && el !== '/') {
              return entries.push(el);
            }
          }
        });
        return entries;
      });
    };

    WebDavBackend.prototype.get = function(key) {
      return jQuery.ajax({
        url: this._url + '/' + key,
        dataType: 'text',
        headers: this._authHeader
      });
    };

    WebDavBackend.prototype.put = function(key, data) {
      var ajaxOpts,
        _this = this;
      ajaxOpts = {
        url: this._url + '/' + key,
        data: data,
        contentType: '',
        type: 'PUT',
        dataType: 'text',
        headers: this._authHeader
      };
      return jQuery.ajax(ajaxOpts).then(function() {
        return _this._changeNotification(key);
      });
    };

    return WebDavBackend;

  })();

  Database = (function() {

    function Database(Backend, backendConfig, _password) {
      var _this = this;
      this._password = _password != null ? _password : 'simple constant password';
      this._changeObservers = [];
      this._backend = new Backend((function(key) {
        return _this._callChangeObservers(key);
      }), backendConfig);
    }

    Database.prototype.save = function(filename, plainData, encryption) {
      var _this = this;
      if (encryption == null) {
        encryption = true;
      }
      return this._backend.put(filename, encryption ? Crypto.encrypt(plainData, this._password) : plainData).then(function() {
        return filename;
      });
    };

    Database.prototype.load = function(filename, encryption) {
      var _this = this;
      if (encryption == null) {
        encryption = true;
      }
      return this._backend.get(filename).then(function(data) {
        if (data == null) {
          return Utilities.rejectedDeferredPromise();
        }
        if (encryption) {
          return Crypto.decrypt(data, _this._password);
        } else {
          return data;
        }
      });
    };

    Database.prototype.savePlain = function(filename, plainData) {
      return this.save(filename, plainData, false);
    };

    Database.prototype.loadPlain = function(filename) {
      return this.load(filename, false);
    };

    Database.prototype.listObjects = function() {
      return this._backend.list();
    };

    Database.prototype.onChange = function(fun) {
      return this._changeObservers.push(fun);
    };

    Database.prototype.clearObservers = function() {
      return this._changeObservers = [];
    };

    Database.prototype._callChangeObservers = function(name) {
      var observer, _i, _len, _ref;
      _ref = this._changeObservers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        observer = _ref[_i];
        observer(name);
      }
      return null;
    };

    return Database;

  })();

  (typeof exports !== "undefined" && exports !== null ? exports : this).Database = Database;

  (typeof exports !== "undefined" && exports !== null ? exports : this).LocalStorageBackend = LocalStorageBackend;

  (typeof exports !== "undefined" && exports !== null ? exports : this).WebDavBackend = WebDavBackend;

}).call(this);