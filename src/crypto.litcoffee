Cryptography Interface
======================

This is an interface to Jeff Mott's CryptoJS.

    Crypto =
        hash: (data) -> CryptoJS.SHA1(data).toString()
        encrypt: (data, password) -> CryptoJS.AES.encrypt(data, password).toString()
        decrypt: (data, password) -> CryptoJS.AES.decrypt(data, password).toString(CryptoJS.enc.Utf8)
        utf8ToBase64: (string) ->
            CryptoJS.enc.Utf8.parse(string).toString(CryptoJS.enc.Base64)

Export the Interface
--------------------
    (exports ? this).Crypto = Crypto