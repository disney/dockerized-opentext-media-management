#!/usr/bin/env node

// Forked from https://github.com/djfarrelly/MailDev/blob/master/bin/maildev at 1472163
// Also adapted from https://github.com/djfarrelly/MailDev/blob/master/docs/api.md#relay-emails

var path = require('path');
var fs = require('fs');

var root = path.join(path.dirname(fs.realpathSync(__filename)), '../');
var MailDev = require(root + '/index.js');

var maildev = new MailDev({
	smtp: 25,
	autoRelay: false,
	outgoingHost: process.env.EMAIL_HOST,
	web: 80,
	webUser: 'tsuper',
	webPass: process.env.OTMM_ADMIN_PASSWORD
});
maildev.listen();

// Rewrite URLs in outgoing emails
maildev.on('new', function (email) {
	// Adapted from http://stackoverflow.com/a/14181136/223225
	fs.readFile(email.source, 'utf8', function (err, source) {
		if (err) return console.error(err);

		// Update the .eml file on disk, as that’s what relayMail actually sends
		source = source.replace(/http:\/\/opentext-media-management-core-app:11090/g, process.env.APP_ROOT_URL);

		// Also update the version in the store, so that the MailDev web UI shows the same content
		if (email.text != null) {
			email.text = email.text.replace(/http:\/\/opentext-media-management-core-app:11090/g, process.env.APP_ROOT_URL)
		}

		// Save the updated .eml file and send it out
		fs.writeFile(email.source, source, 'utf8', function (err) {
			if (err) return console.error(err);

			if (!process.env.DISABLE_OUTBOUND_EMAIL) {
				maildev.relayMail(email, function (err) {
					if (err) return console.error(err);
				});
			}
		});
	});
});
