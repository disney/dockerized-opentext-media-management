// This class allows hitting OpenText Directory Services HTTP endpoints from a shell script, for configuration on Docker container startup.
package com.disney.opentext.OpenTextDirectoryServicesBridge;

// https://github.com/ralfstx/minimal-json
import com.eclipsesource.json.Json;
import com.eclipsesource.json.JsonObject;
import com.eclipsesource.json.JsonArray;
import com.eclipsesource.json.JsonValue;

import java.net.URLEncoder;
import org.apache.http.HttpEntity;
import org.apache.http.util.EntityUtils;
import org.apache.http.HttpResponse;
import org.apache.http.HttpStatus;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpUriRequest;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPut;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.ByteArrayEntity;
import org.apache.http.impl.client.HttpClientBuilder;

import java.util.Optional;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.UnsupportedEncodingException;


public class Bridge {

	private String baseURL;
	private String username;
	private String password;
	private String ticket = null;
	private String action;

	public static void main(String[] args) {
		Bridge api = new Bridge();
		api.ticket = api.getAuthenticationTicket(api.username, api.password);
		api.doAction(args, api);
	}


	public void doAction(String[] args, Bridge api) {
		action = args[0];
		try {
			if (action.equals("get-authentication-ticket")) {
				if (args.length != 3) {
					System.err.println("ERROR: Expected syntax is OpenTextDirectoryServicesBridge.java get-authentication-ticket username new-password");
					System.exit(1);
				} else {
					System.out.println(api.getAuthenticationTicket(args[1], args[2]));
				}
			} else if (action.equals("change-password")) {
				if (args.length != 3) {
					System.err.println("ERROR: Expected syntax is OpenTextDirectoryServicesBridge.java change-password username new-password");
					System.exit(1);
				} else {
					api.changePassword(args[1], args[2]);
				}
			} else if (action.equals("whitelist-trusted-site")) {
				if (args.length != 2) {
					System.err.println("ERROR: Expected syntax is OpenTextDirectoryServicesBridge.java whitelist-trusted-site trusted-site-url");
					System.exit(1);
				} else {
					api.whitelistTrustedSite(args[1]);
				}
			} else if (action.equals("set-synchronization-master-host")) {
				if (args.length != 1) {
					System.err.println("ERROR: Expected syntax is OpenTextDirectoryServicesBridge.java set-synchronization-master-host");
					System.exit(1);
				} else {
					api.setSynchronizationMasterHost();
				}
			} else if (action.equals("consolidate")) {
				if (args.length != 2) {
					System.err.println("ERROR: Expected syntax is OpenTextDirectoryServicesBridge.java consolidate resource");
					System.exit(1);
				} else {
					api.consolidate(args[1]);
				}
			} else if (action.equals("get-resource-by-name")) {
				if (args.length != 3) {
					System.err.println("ERROR: Expected syntax is OpenTextDirectoryServicesBridge.java get-resource-by-name resource");
					System.exit(1);
				} else {
					api.getResourceByName(args[1], args[2]);
				}
			} else if (action.equals("deactivate-resource")) {
				if (args.length != 2) {
					System.err.println("ERROR: Expected syntax is OpenTextDirectoryServicesBridge.java deactivate-resource resource");
					System.exit(1);
				} else {
					api.deactivateResource(args[1]);
				}
			} else {
				System.err.println("ERROR: Unrecognized action");
				System.exit(1);
			}
		} catch (Exception ex) {
			System.err.println("ERROR: Exception in doAction: " + ex.getMessage());
		}
	}


	public Bridge() {
		baseURL = Optional.ofNullable(System.getenv("OTDS_BASE_URL")).orElse("http://opentext-directory-services:8080");
		username = Optional.ofNullable(System.getenv("OTDS_USER")).orElse("otadmin@otds.admin");
		password = System.getenv("OTDS_ADMIN_PASSWORD"); // For a change password request, this is the OLD password, the one that currently works for login and generating a ticket

		ticket = getAuthenticationTicket(username, password);
	}


	public JsonObject makeRequest(String requestType, String endpoint, JsonObject requestBody, int expectedReponseStatusCode) {
		JsonObject responseBody = null;
		HttpClient httpClient = HttpClientBuilder.create().build();

		try {
			// See http://www.programcreek.com/java-api-examples/org.apache.http.client.methods.HttpPut example 2
			HttpUriRequest request = null;
			HttpEntity entity = null;
			if (requestBody != null) {
				entity = new ByteArrayEntity(requestBody.toString().getBytes("UTF-8"));
			}
			if (requestType.equals("get")) {
				request = new HttpGet(baseURL + endpoint);
			} else if (requestType.equals("put")) {
				request = new HttpPut(baseURL + endpoint);
				((HttpPut) request).setEntity(entity);
			} else if (requestType.equals("post")) {
				request = new HttpPost(baseURL + endpoint);
				((HttpPost) request).setEntity(entity);
			} else {
				throw new RuntimeException("ERROR: Unrecognized request type");
			}
			if (requestBody != null) {
				request.addHeader("content-type", "application/json");
			}
			request.addHeader("cache-control", "no-cache");
			if (ticket != null) {
				request.addHeader("OTDSTicket", ticket);
			}

			HttpResponse response = httpClient.execute(request);
			int responseStatusCode = response.getStatusLine().getStatusCode();
			String responseString = "";
			if (responseStatusCode != HttpStatus.SC_NO_CONTENT) {
				HttpEntity responseEntity = response.getEntity();
				responseString = EntityUtils.toString(responseEntity, "UTF-8");
				responseBody = Json.parse(responseString).asObject();
			}
			if (responseStatusCode != expectedReponseStatusCode) {
				throw new RuntimeException("ERROR: HTTP " + response.getStatusLine().getStatusCode() + ": " + responseString);
			}
		} catch (ClientProtocolException ex) {
			System.err.println("ERROR: ClientProtocolException in makeRequest: " + ex.getMessage());
			System.exit(1);
		} catch (IOException ex) {
			System.err.println("ERROR: IOException in makeRequest: " + ex.getMessage());
			System.exit(1);
		} catch (Exception ex) {
			System.err.println("ERROR: Exception in makeRequest: " + ex.getMessage());
			System.exit(1);
		}

		return responseBody;
	}


	public String getAuthenticationTicket(String username, String password) {
		JsonObject requestBody = Json.object().add("userName", username).add("password", password);

		JsonObject responseBody = makeRequest("post", "/otdsws/rest/authentication/credentials", requestBody, HttpStatus.SC_OK);
		return responseBody.get("ticket").asString();
	}


	public void changePassword(String username, String newPassword) {
		String endpoint = new String();
		try {
			endpoint = "/otdsws/rest/users/" + URLEncoder.encode(username, "UTF-8") + "/password";
		} catch (UnsupportedEncodingException ex) {
			System.err.println("ERROR: Unable to parse username '" + username + "'");
			System.exit(1);
		}
		JsonObject requestBody = Json.object().add("newPassword", newPassword);

		try {
			makeRequest("put", endpoint, requestBody, HttpStatus.SC_NO_CONTENT);
			System.out.println("Password successfully changed.");
		} catch (Exception ex) {
			System.err.println("ERROR: Exception in changePassword: " + ex.getMessage());
			System.err.println("Password not changed.");
			System.exit(1);
		}
	}


	public void whitelistTrustedSite(String uri) {
		// The endpoint that handles the list of trusted referral URIs expects an array of ALL trusted sites, so first get the current list, then add one
		JsonObject whitelist = makeRequest("get", "/otdsws/rest/systemconfig/whitelist", null, HttpStatus.SC_OK);
		// whitelist is a JSON object like {"stringList":[]}
		JsonArray trustedSites = whitelist.get("stringList").asArray();

		boolean uriAlreadyTrusted = false;
		for (JsonValue whitelistedUri : trustedSites) {
			if (whitelistedUri.asString().equals(uri)) {
				uriAlreadyTrusted = true;
				break;
			}
		}

		if (uriAlreadyTrusted) {
			System.out.println(uri + " is already in the trusted sites whitelist.");
		} else {
			JsonValue newSite = Json.value(uri);
			trustedSites.add(newSite);

			try {
				JsonObject updatedWhitelist = makeRequest("put", "/otdsws/rest/systemconfig/whitelist", whitelist, HttpStatus.SC_NO_CONTENT);
				System.out.println(uri + " successfully added to the trusted sites whitelist.");
			} catch (Exception ex) {
				System.err.println("ERROR: Exception in whitelistTrustedSite: " + ex.getMessage());
				System.err.println("Trusted sites whitelist unchanged.");
				System.exit(1);
			}
		}
	}

	public void setSynchronizationMasterHost() {
		// In /otds-admin/#systemattributes, the value `directory.bootstrap.MasterHost` a.k.a. “Synchronization Master Host” has a meaningless numeric value by default. It should be set to `opentext-directory-services:41616` automatically on startup.
		String endpoint = "/otdsws/rest/systemconfig/system_attributes/directory.bootstrap.MasterHost";
		JsonObject requestBody = Json.object().add("name", "directory.bootstrap.MasterHost").add("value", "opentext-directory-services:41616");

		try {
			makeRequest("put", endpoint, requestBody, HttpStatus.SC_OK);
			System.out.println("Synchronization Master Host successfully set.");
		} catch (Exception ex) {
			System.err.println("ERROR: Exception in setSynchronizationMasterHost: " + ex.getMessage());
			System.err.println("Synchronization Master Host not set.");
			System.exit(1);
		}
	}

	public void consolidate(String resource) {
		String endpoint = "/otdsws/rest/consolidation";
		String objectToConsolidate = "cn=" + resource + ",ou=Resources,dc=identity,dc=opentext,dc=net";
		String[] objectToConsolidateArr = {objectToConsolidate};
		JsonArray resourceList = Json.array(objectToConsolidateArr);

		JsonObject[] requestBodies = {
			Json.object().add("cleanupGroupsInResource", false).add("cleanupUsersInResource", false).add("objectToConsolidate", objectToConsolidate).add("resourceList", resourceList),
			Json.object().add("consolidateWithIdentityProvider", false).add("objectToConsolidate", resource).add("repair", true).add("resourceList", resourceList)};

		for (JsonObject requestBody : requestBodies) {
			try {
				makeRequest("post", endpoint, requestBody, HttpStatus.SC_NO_CONTENT);
				System.out.println("Consolidation for " + resource + " successful.");
			} catch (Exception ex) {
				System.err.println("ERROR: Exception in consolidate: " + ex.getMessage());
				System.err.println("Consolidation for " + resource + " failed.");
				System.exit(1);
			}
		}
	}

	public void getResourceByName(String name, String property) {
		String endpoint = new String();
		try {
			endpoint = "/otdsws/rest/resources/" + URLEncoder.encode(name, "UTF-8");
		} catch (UnsupportedEncodingException ex) {
			System.err.println("ERROR: Unable to parse resource '" + name + "'");
			System.exit(1);
		}

		try {
			JsonObject resource = makeRequest("get", endpoint, null, HttpStatus.SC_OK);
			String value = resource.get(property).toString();
			value = value.substring(1, value.length() - 1); // Remove quotes
			System.out.println(value);
		} catch (Exception ex) {
			System.err.println("ERROR: Exception in getResourceByName: " + ex.getMessage());
			System.exit(1);
		}
	}

	public void deactivateResource(String resource) {
		String endpoint = new String();
		try {
			endpoint = "/otdsws/rest/resources/" + URLEncoder.encode(resource, "UTF-8") + "/status";
		} catch (UnsupportedEncodingException ex) {
			System.err.println("ERROR: Unable to parse resource '" + resource + "'");
			System.exit(1);
		}

		JsonObject requestBody = Json.object().add("isActivated", false).add("isAuthenticationEnabled", false).add("isSynchronizationEnabled",true);

		try {
			makeRequest("put", endpoint, requestBody, HttpStatus.SC_NO_CONTENT);
			System.out.println("Resource " + resource + " successfully deactivated.");
		} catch (Exception ex) {
			System.err.println("ERROR: Exception in deactivateResource: " + ex.getMessage());
			System.err.println("Resource " + resource + " was not deactivated.");
			System.exit(1);
		}
	}
}
