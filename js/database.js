// Generated by CoffeeScript 1.6.1
(function() {
  var Database, LocalStorageBackend;

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
      var i, ls, _i, _ref, _results;
      ls = this._localStorage;
      _results = [];
      for (i = _i = 0, _ref = ls.length; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
        if (this._keyIsInContext(ls.key(i))) {
          _results.push(this._withoutContext(ls.key(i)));
        }
      }
      return _results;
    };

    LocalStorageBackend.prototype.get = function(key) {
      return this._localStorage[this._context + '/' + key];
    };

    LocalStorageBackend.prototype.put = function(key, data) {
      this._localStorage[this._context + '/' + key] = data;
      return this._changeNotification(key);
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

  Database = (function() {

    function Database(Backend, backendConfig, _password) {
      var _this = this;
      this._password = _password != null ? _password : 'simple constant password';
      this._changeObservers = [];
      this._backend = new Backend((function(key) {
        return _this._callChangeObservers(key);
      }), backendConfig);
    }

    Database.prototype.save = function(filename, plainData) {
      this._backend.put(filename, Crypto.encrypt(plainData, this._password));
      return null;
    };

    Database.prototype.load = function(filename) {
      return Crypto.decrypt(this._backend.get(filename), this._password);
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

}).call(this);
