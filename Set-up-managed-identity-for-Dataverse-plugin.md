---
title: Set up managed identity for a Dataverse plug-in
description: Step-by-step guide to enable a Dynamics 365 Online plug-in to acquire AAD tokens via managed identity, based on the AIA-AICLAIMS-MY-DEV implementation.
environment: AIA-AICLAIMS-MY-DEV
last-implemented: 2026-08-03
---

# Set up managed identity for a Dataverse plug-in

This article shows how to configure a Dynamics 365 (Dataverse) plug-in to acquire Microsoft Entra ID (AAD) tokens by using **managed identity**, so the plug-in can call protected resources without storing any client secret or certificate password. The mechanism is built on **Federated Identity Credentials (FIC)**.

This guide records the values and steps from a completed, verified implementation in the **AIA-AICLAIMS-MY-DEV** environment.

> [!NOTE]
> Managed identity for Dataverse plug-ins is **generally available (GA)** as of June 15, 2025, and is supported for production use.

## Prerequisites

- An **App registration** in Microsoft Entra ID.
- An X.509 **code-signing certificate** (self-signed is acceptable for test).
- **Visual Studio** with the Dataverse plug-in project (.NET Framework 4.6.2).
- **Windows SDK** (for `signtool`) and **OpenSSL** (Git Bash).
- **Plugin Registration Tool** and **Dataverse REST Builder**.
- **Power Platform** admin permission (to create the application user).

## Reference values

The following values are from the AIA-AICLAIMS-MY-DEV implementation. Substitute your own where you reproduce this in another environment.

| Item | Value |
|------|-------|
| Application (client) ID | `9F3D07CA-381E-43FC-8BEF-76DD03B460D6` |
| Tenant ID | `7f2c1900-9fd4-4b89-91d3-79a649996f0a` |
| Environment ID | `59b86021-2790-4a26-b386-15823676bbf4` |
| Encoded tenant ID | `ABksf9SfiUuR03mmSZlvCg` |
| Managed identity record ID | `0bb91e27-1d0c-4a60-973c-ed810d9695ff` |
| Plug-in assembly ID | `cadc6113-ec1d-43ca-a0d7-62e7f3571864` |
| Certificate SHA-1 (thumbprint) | `EC61C07E93C0F9B97E9001864BE990530237EFCC` |
| Certificate SHA-256 | `226154c9d2662c1c5fbc213c47d61aa2b49f0d8d51dab6470084a09da46eea00` |
| Certificate expiry | 2029-06-14 |
| Organization URL | `https://aia-aiclaims-my-dev.crm5.dynamics.com` |
| App user name | `sp-my01-sea-d-ripple01-claimmodapp` |

---

## Step 1: Create the signing certificate

> [!IMPORTANT]
> Managed identity requires the plug-in assembly to be signed with an **X.509 certificate (Authenticode)**. A strong-name (`.snk`) signature is not sufficient because it has no thumbprint. Both signatures can coexist.

1. Generate a private key and self-signed certificate in Git Bash.

   > [!NOTE]
   > Prefix the command with `MSYS_NO_PATHCONV=1` to prevent Git Bash from converting the `-subj` path.

   ```bash
   MSYS_NO_PATHCONV=1 openssl req -x509 -newkey rsa:2048 \
     -keyout private.key \
     -out certificate.crt \
     -days 1095 \
     -nodes \
     -subj "/CN=MyPlugin-Test/O=MyOrg-AIA/C=CN"
   ```

2. Convert the certificate and key to a PFX for Windows/.NET use. The password is read from an environment variable.

   ```bash
   openssl pkcs12 -export \
     -out plugin.pfx \
     -inkey private.key \
     -in certificate.crt \
     -passout env:PfxPassword
   ```

3. Compute the certificate **SHA-256** hash. This value is used in the FIC subject in Step 3.

   ```bash
   # Option A: openssl fingerprint (computes hash over the DER content)
   openssl x509 -in certificate.crt -fingerprint -sha256 -noout

   # Option B: convert to DER .cer, then CertUtil (must match Option A)
   openssl x509 -in certificate.crt -outform DER -out certificate.cer
   certutil -hashfile certificate.cer SHA256
   ```

   > [!WARNING]
   > `openssl x509 -fingerprint` hashes the DER content for both PEM and DER files (correct). `certutil -hashfile` hashes the file bytes, so run it against a **DER-encoded** `.cer` file, not a PEM `.crt`.

## Step 2: Sign the plug-in assembly

1. In the Visual Studio project, open **Properties** > **Build Events** > **Post-build event command line** and add:

   ```
   signtool sign /f "$(ProjectDir)plugin.pfx" /p "%PfxPassword%" /fd SHA256 /tr http://timestamp.sectigo.com /td SHA256 "$(TargetPath)"
   ```

   > [!TIP]
   > If the build fails with exit code **9009**, `signtool` is not on the PATH. Add the Windows SDK x64 folder, for example `C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64`, and restart Visual Studio.

2. Store the PFX password in a Windows environment variable named `PfxPassword`. Do not hardcode the password.

3. Build the project. Verify the signature:

   ```bash
   signtool verify /pa /v "...\Company.CRM.Plugins.dll"
   ```

   > [!NOTE]
   > A self-signed certificate produces a "certificate chain ... not trusted" warning. This is expected and does not affect Dataverse, which only compares the thumbprint. To confirm the assembly is signed, `certutil -dump <dll>` should show `CMSG_SIGNED`.

## Step 3: Configure the federated identity credential

In the Azure portal, go to your **App registration** > **Certificates & secrets** > **Federated credentials** > **Add credential**, and select the **Other issuer** scenario.

> [!IMPORTANT]
> Use the format from Microsoft Learn. Older community formats are outdated and cause error `AADSTS700213` (no matching federated identity record).

1. Set **Issuer**:

   ```
   https://login.microsoftonline.com/7f2c1900-9fd4-4b89-91d3-79a649996f0a/v2.0
   ```

2. Set **Type** to `Explicit subject identifier`.

3. Set **Value** (subject identifier):

   ```
   /eid1/c/pub/t/ABksf9SfiUuR03mmSZlvCg/a/qzXoWDkuqUa3l6zM5mM0Rw/n/plugin/e/59b86021-2790-4a26-b386-15823676bbf4/h/226154c9d2662c1c5fbc213c47d61aa2b49f0d8d51dab6470084a09da46eea00
   ```

4. Leave **Audience** as the default `api://AzureADTokenExchange`.

### Subject segments

| Segment | Meaning | Variable |
|---------|---------|----------|
| `/eid1` | Format version | Fixed |
| `/c/pub` | Public cloud (Geo = APAC is public) | Fixed |
| `/t/{encodedTenantId}` | Base64URL-encoded tenant ID | Per tenant |
| `/a/qzXoWDkuqUa3l6zM5mM0Rw` | Internal value | **Do not change** |
| `/n/plugin` | Plug-in component | Fixed |
| `/e/{environmentId}` | Environment ID (full GUID with dashes) | Per environment |
| `/h/{sha256}` | Certificate SHA-256 | Per certificate |

### Compute the encoded tenant ID

The `{encodedTenantId}` is **not** the plain tenant GUID. For this environment the value is already computed and verified:

```
Tenant ID:          7f2c1900-9fd4-4b89-91d3-79a649996f0a
Encoded tenant ID:  ABksf9SfiUuR03mmSZlvCg
```

Reuse the value above for this environment. You only need to recompute it for a **different tenant**.

> [!NOTE]
> The encoding is: tenant GUID -> raw bytes in **.NET little-endian order** (`Guid.ToByteArray()` uses little-endian for the first three GUID fields) -> **Base64URL** (`+` becomes `-`, `/` becomes `_`, trailing `=` removed). The byte order is the tricky part.

To compute it for a new tenant without PowerShell, use one of the following.

**Option A: Git Bash + OpenSSL (reorders bytes to little-endian).**

```bash
TENANT_ID=7f2c1900-9fd4-4b89-91d3-79a649996f0a

# Strip dashes, then reorder the first three fields to little-endian (.NET ToByteArray order)
HEX=$(echo "$TENANT_ID" | tr -d '-')
LE="${HEX:6:2}${HEX:4:2}${HEX:2:2}${HEX:0:2}${HEX:10:2}${HEX:8:2}${HEX:14:2}${HEX:12:2}${HEX:16:16}"

# Convert little-endian hex to Base64, then to Base64URL
echo "$LE" | xxd -r -p | base64 | tr '+/' '-_' | tr -d '='
# Result: ABksf9SfiUuR03mmSZlvCg
```

**Option B: C# helper (run in Visual Studio, LINQPad, or dotnet-script).**

```csharp
var tenantId = "7f2c1900-9fd4-4b89-91d3-79a649996f0a";
var bytes = System.Guid.Parse(tenantId).ToByteArray();   // .NET little-endian byte order
var b64url = System.Convert.ToBase64String(bytes)
    .TrimEnd('=').Replace('+', '-').Replace('/', '_');
System.Console.WriteLine(b64url);
// Result: ABksf9SfiUuR03mmSZlvCg
```

## Step 4: Deploy the signed assembly

Register the signed DLL by using the **Plugin Registration Tool**:

- **Isolation Mode**: Sandbox (required for Online)
- **Location**: Database (required for Online)

Record the generated **plug-in assembly ID**: `cadc6113-ec1d-43ca-a0d7-62e7f3571864`.

## Step 5: Create and link the managed identity record

Use a REST client such as **Dataverse REST Builder** (DRB). In DRB, a POST maps to **Create** and a PATCH maps to **Update**.

1. Create the managed identity record.

   ```http
   POST https://aia-aiclaims-my-dev.crm5.dynamics.com/api/data/v9.0/managedidentities

   {
     "applicationid":     "9F3D07CA-381E-43FC-8BEF-76DD03B460D6",
     "managedidentityid": "0bb91e27-1d0c-4a60-973c-ed810d9695ff",
     "credentialsource":  2,
     "subjectscope":      1,
     "tenantid":          "7f2c1900-9fd4-4b89-91d3-79a649996f0a",
     "version":           2
   }
   ```

   | Field | Meaning |
   |-------|---------|
   | `applicationid` | App registration client ID |
   | `credentialsource: 2` | Managed client |
   | `subjectscope: 1` | Environment scope (same tenant; suits multi-environment) |
   | `version: 2` | Current managed identity record format |

2. Link the managed identity to the plug-in assembly.

   ```http
   PATCH https://aia-aiclaims-my-dev.crm5.dynamics.com/api/data/v9.0/pluginassemblies(cadc6113-ec1d-43ca-a0d7-62e7f3571864)

   {
     "managedidentityid@odata.bind": "/managedidentities(0bb91e27-1d0c-4a60-973c-ed810d9695ff)"
   }
   ```

   > [!NOTE]
   > Create the record first, then link it. The PATCH references the managed identity record GUID.

## Step 6: Register the plug-in step

In the Plugin Registration Tool, register a step for `CallExternalApiPlugin`:

- **Message**: Create
- **Primary Entity**: demo_equipmenttype
- **Stage**: PostOperation
- **Execution Mode**: Synchronous

## Step 7: Create the application user

> [!IMPORTANT]
> To access Dataverse resources, the app must be an application user in the environment. Otherwise calls fail with **403** ("The user is not a member of the organization").

1. Go to **Power Platform admin center** > **Environments** > **AIA-AICLAIMS-MY-DEV** > **Settings** > **Users + permissions** > **Application users** > **+ New app user**.
2. Select **Add an app**, then search for `9F3D07CA-381E-43FC-8BEF-76DD03B460D6`.
3. Set **Business unit** to the root business unit (AHS CRM).
4. Assign a security role, for example **System Administrator** for testing.

   > [!WARNING]
   > Do not assign the **Support User** role. It is a system role that cannot be assigned to users ("The Support User role cannot be assigned to user(s) or team(s)"). Choose System Administrator or another assignable role.

## Step 8: Validate

Trigger the plug-in by creating a `demo_equipmenttype` record, then inspect the plug-in trace or exception details.

A successful run shows:

```
Access token acquired via Managed Identity.
Calling external API: /api/data/v9.2/WhoAmI
External API call succeeded.
```

---

## Code notes

Acquire the token and call the resource:

```csharp
// Obtain IManagedIdentityService from the service provider
var managedIdentityService = (IManagedIdentityService)
    serviceProvider.GetService(typeof(IManagedIdentityService));

// Acquire the token
var scopes = new List<string> { "https://aia-aiclaims-my-dev.crm5.dynamics.com/.default" };
string accessToken = managedIdentityService.AcquireToken(scopes);
```

| Consideration | Detail |
|---------------|--------|
| TLS 1.2 | .NET Framework 4.6.2 must enable it explicitly: `ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;` |
| GET vs POST | Function endpoints such as WhoAmI must use `GetAsync`. Using POST returns 405/404. |
| Async in plug-ins | Plug-ins run synchronously; call async APIs with `.GetAwaiter().GetResult()`. |
| Scope format | `<resource-root>/.default`, for example `https://<org>.crm5.dynamics.com/.default`. This is an OAuth scope, not a web URL (opening it in a browser returns 404, which is expected). |
| Plugin Profiler | During local profiler debugging, `IManagedIdentityService` returns null (the simulated context does not support MI). Validate only in the real environment via tracing. |

## Troubleshooting

| Error | Meaning | Resolution |
|-------|---------|------------|
| `AADSTS700213` | No matching FIC record | Fix the FIC format — check issuer, encoded tenant ID, and SHA-256 (not SHA-1). |
| 401 Unauthorized | Token invalid | The resource does not accept the token. |
| 403 "not a member" | Token valid, but not an org member | Create the application user (Step 7). |
| 404 No HTTP resource | Wrong URL path | Token valid and member; check the URL and use GET. |
| 405 Method Not Allowed | Wrong HTTP method | Use GET for function endpoints. |
| 9009 (build) | `signtool` not found | Add the Windows SDK x64 folder to PATH. |

> [!TIP]
> The progression 403 -> 404 -> 200 reflects progress: a **403 (not a 401) already proves the token is valid** — the identity is recognized but lacks permission. Once the application user is configured, only a URL/method detail remains.

## Certificate rotation

> [!IMPORTANT]
> Certificate expiry is the main long-term risk. This certificate expires on **2029-06-14**.

- The thumbprint and SHA-256 bind the entire certificate. Any change (including renewal) changes the hash.
- After expiry, managed identity cannot acquire a token (Entra ID rejects expired certificates).
- Timestamping keeps the Authenticode signature valid but does not exempt the certificate from rotation.

Rotation flow:

1. Generate a new certificate with a long validity. Reuse the OpenSSL command from Step 1 and set `-days` accordingly (for example `-days 1095` for ~3 years).
2. Re-sign the assembly (Step 2).
3. Compute the new certificate SHA-256 and update the FIC subject with the new `/h/{sha256}` (Step 3).
4. Redeploy the assembly (Step 4).
5. Validate (Step 8).

> [!NOTE]
> A "dual FIC" overlap minimizes the interruption window, but zero downtime is not achievable because the assembly must be redeployed. For zero-downtime, certificate-free operation, consider an Azure Function proxy with managed identity instead.

## Security notes

- Add `plugin.pfx`, `private.key`, and `certificate.crt` to `.gitignore`.
- Store passwords (such as the PFX password) in environment variables, not in code or build events.
- Do not log the full token in the plug-in trace log. If diagnostics are needed, log the JWT payload claims (no signature, cannot be misused).
- In production, apply least privilege and tighten the application user's security role to only what is required.

## Related information

- Microsoft Learn: [Set up Power Platform managed identity for Dataverse plug-ins or plug-in packages](https://learn.microsoft.com/en-us/power-platform/admin/set-up-managed-identity) (updated 2025-12-11)
- Feature status: Generally available since 2025-06-15
