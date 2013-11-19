// Generated by CoffeeScript 1.6.1
(function() {
  var Crypto;

  Crypto = {
    hash: function(data) {
      return CryptoJS.SHA1(data).toString();
    },
    encrypt: function(data, password) {
      return CryptoJS.AES.encrypt(data, password).toString();
    },
    decrypt: function(data, password) {
      return CryptoJS.AES.decrypt(data, password).toString(CryptoJS.enc.Utf8);
    },
    utf8ToBase64: function(string) {
      return CryptoJS.enc.Utf8.parse(string).toString(CryptoJS.enc.Base64);
    }
  };

  (typeof exports !== "undefined" && exports !== null ? exports : this).Crypto = Crypto;

}).call(this);
