
import java.io.IOException;
import java.nio.file.*;
import java.util.concurrent.Callable;

import org.json.JSONObject;

import kong.unirest.*;
import picocli.CommandLine;
import picocli.CommandLine.*;

@Command(name="code_blocks")
class code_blocks implements Callable<Integer> {

	@Option(names = {"-u"}, required=true, description="Username to login to Control-M/Enterprise Manager")
	private String user;

	private String pass;

	@Option(names = {"-pf"}, description="The file that contains the password to login to Control-M/Enterprise Manager")
	private String pass_file = null;

	@Option(names = {"-h"}, required=true, description="Control-M/Enterprise Manager Hostname")
	private String host;

	@Option(names = {"-i"}, description="Disable SSL Certificate Validation")
	private boolean insecure = false;

	@Option(names = {"--help"}, usageHelp=true, description="show this help message and exit")
	private boolean help = false;

	public static void main(String[] args) {
		int exitCode = new CommandLine(new code_blocks()).execute(args);
		System.exit(exitCode);
	}

	@Override
	public Integer call() {
		// Ignore SSL verification if we're told to do so
		Unirest.config().verifySsl(!insecure);

		// Retrieve the password
		if (pass_file != null) {
			try {
				pass = new String(Files.readAllBytes(Paths.get(pass_file)), "UTF-8").trim();
			} catch (IOException e) {
				System.err.printf("Unable to read password file: %s\n", pass_file);
				System.err.println(e.getMessage());
				Unirest.shutDown();
				return 1;
			}
		} else {
			System.out.print("Password: ");
			pass = new String(System.console().readPassword());
		}

		HttpResponse<JsonNode> response;

		// Login
		try {
			response = Unirest.post(String.format("https://%s/automation-api/session/login", host))
				.header("Content-Type", "application/json")
				.body(String.format("{\"username\":\"%s\", \"password\":\"%s\"}", user, pass))
				.asJson();
		} catch (UnirestException e) {
			System.err.println(e.getMessage());
			Unirest.shutDown();
			return 1;
		}

		// Handle error
		if (!response.isSuccess()) {
			for (Object m: response.getBody().getObject().getJSONArray("errors"))
				System.err.println(((JSONObject)m).getString("message"));
			Unirest.shutDown();
			return 1;
		}

		String token = response.getBody().getObject().getString("token");

		System.out.println(token);

		// Logout
		try {
			response = Unirest.post(String.format("https://%s/automation-api/session/logout", host))
					.header("Content-Type", "application/json")
					.header("Authorization", String.format("Bearer %s", token))
					.asJson();
		} catch (UnirestException e) {
			System.err.println(e.getMessage());
			Unirest.shutDown();
			return 1;
		}

		// Handle error
		if (!response.isSuccess()) {
			for (Object m: response.getBody().getObject().getJSONArray("errors"))
				System.err.println(((JSONObject)m).getString("message"));
			Unirest.shutDown();
			return 1;
		}

		Unirest.shutDown();
		return 0;
	}
}
