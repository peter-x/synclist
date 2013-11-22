// Generated by CoffeeScript 1.6.1
(function() {
  var Item,
    __slice = [].slice,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Item = (function() {

    function Item(id, revision, revisions, creation, resolution, modification, category, text, position) {
      this.id = id;
      this.revision = revision != null ? revision : '';
      this.revisions = revisions != null ? revisions : [];
      this.creation = creation != null ? creation : 0;
      this.resolution = resolution != null ? resolution : 0;
      this.modification = modification != null ? modification : 0;
      this.category = category != null ? category : '';
      this.text = text != null ? text : '';
      this.position = position != null ? position : 0;
    }

    Item.createFromJSON = function(filename, text) {
      var data, id, m, rev, revision, _i, _len, _ref, _ref1, _ref2, _ref3, _ref4;
      try {
        data = JSON.parse(text);
      } catch (error) {
        return null;
      }
      if (typeof filename !== 'string' || typeof data !== 'object') {
        return null;
      }
      if (!((((typeof data.creation === (_ref2 = typeof data.resolution) && _ref2 === (_ref1 = typeof data.modification)) && _ref1 === (_ref = typeof data.position)) && _ref === 'number') && (typeof data.category === (_ref3 = typeof data.text) && _ref3 === 'string'))) {
        return null;
      }
      try {
        _ref4 = data.revisions.slice(0);
        for (_i = 0, _len = _ref4.length; _i < _len; _i++) {
          rev = _ref4[_i];
          if (typeof rev !== 'string') {
            return null;
          }
        }
      } catch (error) {
        return null;
      }
      m = /^([a-zA-Z0-9]+)-([1-9][0-9]*-[a-zA-Z0-9]+)$/.exec(filename);
      if (!m) {
        return null;
      }
      filename = m[0], id = m[1], revision = m[2];
      return new Item(id, revision, data.revisions.slice(0), data.creation, data.resolution, data.modification, data.category, data.text, data.position);
    };

    Item.createNew = function(text, category, position) {
      var item, timestamp, _ref;
      if (category == null) {
        category = '';
      }
      if (position == null) {
        position = 0;
      }
      if (!((typeof text === (_ref = typeof category) && _ref === 'string') && typeof position === 'number')) {
        return null;
      } else {
        timestamp = (+(new Date)) / 1000.0;
        item = new Item(Item.generateID(), '', [], timestamp, 0, timestamp, category, text, position);
        return item.updateRevision();
      }
    };

    Item.prototype.getID = function() {
      return this.id;
    };

    Item.prototype.getRevision = function() {
      return this.revision;
    };

    Item.prototype.getRevisionsIncludingSelf = function() {
      return [this.revision].concat(this.revisions);
    };

    Item.prototype.getCreated = function() {
      return this.creation;
    };

    Item.prototype.isResolved = function() {
      return this.resolution > 0;
    };

    Item.prototype.getResolved = function() {
      return this.resolution;
    };

    Item.prototype.setResolved = function(resolved) {
      if (resolved == null) {
        resolved = true;
      }
      return this.changedCopy(function() {
        return this.resolution = resolved ? (+(new Date)) / 1000.0 : 0;
      });
    };

    Item.prototype.getCategory = function() {
      return this.category;
    };

    Item.prototype.setCategory = function(category) {
      return this.changedCopy(function() {
        return this.category = category;
      });
    };

    Item.prototype.getText = function() {
      return this.text;
    };

    Item.prototype.setText = function(text) {
      return this.changedCopy(function() {
        return this.text = text;
      });
    };

    Item.prototype.getPosition = function() {
      return this.position;
    };

    Item.prototype.setPosition = function(position) {
      return this.changedCopy(function() {
        return this.position = position;
      });
    };

    Item.prototype.jsonEncode = function() {
      this.revisions = Item.sortRevisions.apply(Item, this.revisions);
      return JSON.stringify({
        revisions: this.revisions,
        creation: this.creation,
        resolution: this.resolution,
        modification: this.modification,
        category: this.category,
        text: this.text,
        position: this.position
      });
    };

    Item.comparator = function(a, b) {
      return a.position - b.position;
    };

    Item.prototype.isNewerThan = function(otherItem) {
      return (otherItem == null) || Item.revisionComparator(this.revision, otherItem.revision) > 0;
    };

    Item.prototype.mergeWith = function(item, base) {
      var category, creation, modification, position, resolution, revision, revisions, text;
      revision = Item.sortRevisions(this.revision, item.revision)[1];
      revisions = Item.sortRevisions.apply(Item, [this.revision, item.revision].concat(__slice.call(this.revisions), __slice.call(item.revisions)));
      creation = base.creation;
      resolution = (item.resolution > 0) === (this.resolution > 0) ? Math.min(item.resolution, this.resolution) : (item.resolution > 0) !== (base.resolution > 0) ? item.resolution : this.resolution;
      modification = Math.max(this.modification, item.modification);
      text = this.text === item.text ? this.text : this.text === base.text ? item.text : item.text === base.text ? this.text : this.text < item.text ? this.text + ', ' + item.text : item.text + ', ' + this.text;
      category = this.category === item.category ? this.category : this.category === base.category ? item.category : item.category === base.category ? this.category : this.category < item.category ? this.category + ', ' + item.category : item.category + ', ' + this.category;
      position = this.position === base.position ? item.position : item.position === base.position ? this.position : Math.min(this.position, item.position);
      return new Item(this.id, revision, revisions, creation, resolution, modification, category, text, position).updateRevision();
    };

    Item.prototype.getLatestCommonAncestor = function(item) {
      var i, len, _ref, _ref1;
      if (this.revision === item.revision || (_ref = this.revision, __indexOf.call(item.revisions, _ref) >= 0)) {
        return this.revision;
      } else if (_ref1 = item.revision, __indexOf.call(this.revisions, _ref1) >= 0) {
        return item.revision;
      } else {
        len = Math.min(this.revisions.length, item.revisions.length);
        i = 0;
        while (i < len && this.revisions[i] === item.revisions[i]) {
          i += 1;
        }
        if (i === 0) {
          return null;
        } else {
          return this.revisions[i - 1];
        }
      }
    };

    Item.prototype.changedCopy = function(mod) {
      var item;
      item = new Item(this.id, this.revision, this.revisions.slice(0), this.creation, this.resolution, this.modification, this.category, this.text, this.position);
      mod.call(item);
      return item.adjustModificationAndUpdateRevision();
    };

    Item.prototype.adjustModificationAndUpdateRevision = function() {
      this.modification = (+(new Date)) / 1000.0;
      return this.updateRevision();
    };

    Item.prototype.updateRevision = function() {
      var data;
      if (this.revision.length > 0) {
        this.revisions.push(this.revision);
      }
      data = this.jsonEncode();
      this.revision = this.getIncrementedRevision(data);
      return this;
    };

    Item.prototype.getIncrementedRevision = function(data) {
      var rev, revisionNumber;
      rev = this.revision || '0-';
      revisionNumber = +(rev.split('-'))[0];
      return "" + (revisionNumber + 1) + "-" + (Crypto.hash(data));
    };

    Item.generateID = function(length) {
      var characters, i;
      if (length == null) {
        length = 22;
      }
      characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
      return ((function() {
        var _i, _results;
        _results = [];
        for (i = _i = 1; 1 <= length ? _i <= length : _i >= length; i = 1 <= length ? ++_i : --_i) {
          _results.push(characters[Math.floor(Math.random() * characters.length)]);
        }
        return _results;
      })()).join('');
    };

    Item.sortRevisions = function() {
      var r, revisions, revs, _i, _len;
      revisions = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      revs = {};
      for (_i = 0, _len = revisions.length; _i < _len; _i++) {
        r = revisions[_i];
        revs[r] = 1;
      }
      revs = (function() {
        var _results;
        _results = [];
        for (r in revs) {
          _results.push(r);
        }
        return _results;
      })();
      revs.sort(Item.revisionComparator);
      return revs;
    };

    Item.revisionComparator = function(a, b) {
      var aNum, aRev, bNum, bRev, _ref, _ref1;
      _ref = a.split('-'), aNum = _ref[0], aRev = _ref[1];
      _ref1 = b.split('-'), bNum = _ref1[0], bRev = _ref1[1];
      if (+aNum !== +bNum) {
        return aNum - bNum;
      } else if (aRev > bRev) {
        return 1;
      } else if (bRev > aRev) {
        return -1;
      } else {
        return 0;
      }
    };

    return Item;

  })();

  (typeof exports !== "undefined" && exports !== null ? exports : this).Item = Item;

}).call(this);
