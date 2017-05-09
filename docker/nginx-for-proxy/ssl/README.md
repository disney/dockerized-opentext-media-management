Create `localhost.key` and `localhost.pem` files via:

```sh
openssl req -config openssl.conf -new -x509 -sha256 -newkey rsa:2048 -nodes  -days 3650 \
  -keyout localhost.key -out localhost.pem \
  -subj "/C=OZ/ST=Land of Oz/L=Emerald City/O=No Place Like Localhost/OU=Localhost/CN=Localhost"
```

using the `openssl.conf` in this folder, based on [https://stackoverflow.com/a/27931596](https://stackoverflow.com/a/27931596).

Then, the certificate can be trusted via these steps:

1. Double-click the file to open it in Keychain Access.
2. You should see a dialog box asking “Do you want to add the certificate(s) from the file “localhost.pem” to a keychain?” Set the keychain to `System` and click `Add`.
3. In the Keychain Access main window, in the left sidebar under `Keychains` choose `System`. You should see “localhost” in the list. Double-click it to open it.
4. Under `Trust`, next to “When using this certificate:” choose “Always Trust”.

See also [https://bugs.chromium.org/p/chromium/issues/detail?id=704199](https://bugs.chromium.org/p/chromium/issues/detail?id=704199).

You also need to create a `dhparam.pem` file:

```sh
openssl dhparam -dsaparam -out dhparam.pem 4096
```
