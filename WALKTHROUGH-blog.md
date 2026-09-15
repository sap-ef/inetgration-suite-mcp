# Walkthrough — Governed MCP Server in SAP Integration Suite (blog run)

> End-to-end record of building a **governed MCP Server** from the SAP BTP
> Resource Consumption (UAS Reporting) API in SAP Integration Suite, then
> connecting it to Claude Code.
>
> This run uses a **`blog` prefix** on every object created (`blog `/`blog_`)
> so nothing collides with the existing (non-blog) objects on the tenant. It
> reuses the pre-existing Destination **`UAS_Reporting_Destination`** rather
> than creating a new one.
>
> Screenshots for every step live in [`assets/walkthrough/`](assets/walkthrough/).

---

## What gets created (blog-prefixed)

| Object | Value |
|---|---|
| Integration Package | `blog …` (new package) |
| API Artifact | from `uas-reporting-oas3-sap-mcp-blog.json` — title **blog Resource Consumption** |
| Destination (reused) | `UAS_Reporting_Destination` |
| MCP Server | `blog_Resource_Consumption_mcpServer`, MCP Path `/blog-uas-reporting` |
| Developer Hub Product | **blog BTP Usage Reporting MCP** (`blog_BTP_Usage_Reporting_MCP`, Type **AI**) |
| Agent Subscription | **blog Claude Code Agent** |
| MCP Server URL | `https://<your-integration-cell-host>/blog-uas-reporting` |

Two independent auth layers:

| Layer | Secures | Credentials |
|---|---|---|
| MCP Client → MCP Server | Claude Code → MCP endpoint | OAuth via Developer Hub Agent Subscription (Tenant XSUAA) |
| MCP Server → Backend API | Integration Suite → backend | OAuth2ClientCredentials via BTP Destination `UAS_Reporting_Destination` |

---

## Phase 1 — API Artifact

### 1.1 Integration Suite home
Design-time capability, **Integrations and APIs**.

![Integration Suite home](assets/walkthrough/00-is-home.png)

### 1.2 Create the Integration Package
A **new** `blog`-prefixed package (not the existing one).

![Create package](assets/walkthrough/01-create-package.png)

### 1.3 Add API → upload the OpenAPI spec, provide details
`Add → API → Specification → Upload` with
[`uas-reporting-oas3-sap-mcp-blog.json`](uas-reporting-oas3-sap-mcp-blog.json).

Key fields in the spec (`info` block):
- `x-apiProvider`: **`UAS_Reporting_Destination`** (the reused Destination)
- `x-relativeUrl`: **`/reports/v1`**
- paths: `/cloudCreditsDetails`, `/monthlyDirectoryUsage`, `/monthlySubaccountsCost`, `/monthlyUsage`, `/subaccountUsage`

![Add API — provide details](assets/walkthrough/02-add-api-details.png)

### 1.4 API Artifact overview
![API Artifact overview](assets/walkthrough/03-api-artifact-overview.png)

### 1.5 API policies
Open the **Policies** editor.

![Policies view](assets/walkthrough/04-policies-view.png)

### 1.6 Authorization policy
- **Authorization Type**: OAuth Scope or Developer Key
- **Scope**: `API.invoke`
- **Trust Upstream MCP Authorization**: ✓ enabled

![Authorization policy settings](assets/walkthrough/05-authorization-policy-settings.png)

### 1.7 Save → Deploy → Started
![API deployed / started](assets/walkthrough/06-api-deployed-started.png)

---

## Phase 2 — MCP Server

### 2.1 Add MCP Server → Source: API
![Select source type](assets/walkthrough/07-mcp-select-source-type.png)

### 2.2 MCP Server details
- **Name**: `blog_Resource_Consumption_mcpServer`
- **MCP Path**: `/blog-uas-reporting`
- **Virtual Host**: your Integration Cell virtual host

![Provide MCP details](assets/walkthrough/08-mcp-provide-details.png)

### 2.3 Select operations → create tools
The API operations become MCP tools. Tool **descriptions** are what an AI agent
reads to decide which tool to call — keep them clear.

![Create tools](assets/walkthrough/09-mcp-create-tools.png)

### 2.4 MCP Server overview
![MCP overview created](assets/walkthrough/10-mcp-overview-created.png)

### 2.5 MCP configuration — source & tools
![MCP config — source](assets/walkthrough/11-mcp-config-source.png)
![MCP config — tools](assets/walkthrough/12-mcp-config-tools.png)

### 2.6 MCP policies flow
![MCP policies flow](assets/walkthrough/13-mcp-policies-flow.png)

### 2.7 Save → Deploy → Started
![MCP deployed / started](assets/walkthrough/14-mcp-deployed-started.png)

---

## Phase 3 — Publish to Developer Hub

> **Gotcha (why not the design-time "Engage" capability):** Engage → Products →
> Create only offers **Type = API**, with no MCP option — so an MCP product
> can't be created there. The screenshots below show that dead end, then the
> correct path via the **Developer Hub** portal.
>
> ![Engage products empty](assets/walkthrough/15-engage-products-empty.png)
> ![Engage product form (API-only)](assets/walkthrough/16-product-overview-filled.png)

The correct path is the **Developer Hub** (API Business Hub Enterprise) portal,
a separate URL, e.g.
`https://<your-developer-hub-host>/`.

### 3.1 Discover APIs / Developer Hub landing
![Discover APIs](assets/walkthrough/17-discover-apis.png)
![Developer Hub landing](assets/walkthrough/18-developer-hub-landing.png)

### 3.2 Admin Center → Content → Manage Content
**Hover** (do not click) **Admin Center** in the top nav → the menu appears →
**Content**. In Manage Content, the **Products** tab → Create only offers
Type = API, so switch to the **Business Systems** tab instead.

![Manage Content — products](assets/walkthrough/19-manage-content-products.png)

### 3.3 Business Systems → open your business system → MCP Servers tab → select the MCP Server
Selecting the MCP Server here lets you create a product **with the MCP Server
already associated** (the API-only Products path can't do this).

![MCP Server selected](assets/walkthrough/20-mcp-server-selected.png)

### 3.4 Create Product (MCP Server pre-associated)
- **Name**: blog BTP Usage Reporting MCP
- **Type**: AI
- Description: governed MCP Server for querying SAP BTP resource consumption (blog walkthrough)

![Create Product — filled](assets/walkthrough/21-create-product-filled.png)

### 3.5 Publish → asynchronous request created
![Publish request created](assets/walkthrough/22-publish-request-created.png)

### 3.6 Track in Admin Center → Scheduled Requests
Product creation/publish is async. Status goes **In Progress → Success**.

![Scheduled Requests — In Progress](assets/walkthrough/23-scheduled-requests-inprogress.png)
![Scheduled Requests — Success](assets/walkthrough/24-scheduled-requests-success.png)

### 3.7 Published product overview
![Product overview — published](assets/walkthrough/25-product-overview-published.png)

---

## Phase 4 — Agent Subscription

### 4.1 Subscribe → Create New Subscription for Agent
From the product **Overview → Subscribe → Create New Subscription for Agent**.
- **Name**: blog Claude Code Agent
- **Short Text**: Agent subscription for Claude Code (blog walkthrough)
- **Callback URL**: *left empty*

![Create Agent Subscription — filled](assets/walkthrough/26-create-agent-subscription-filled.png)

> **Note (Create button disabled):** if you type a Callback URL that fails the
> URL validation the **Create** button stays disabled. Leaving the field empty
> is accepted and enables Create.
>
> **Note (`"You can only create subscription on behalf of developers"`):** if you
> hit this, go to *Admin Center → Users* and register your user as an
> **Application Developer**.

### 4.2 Subscription finalizing (async)
"Your subscription is being finalized. Please refresh the page after some time."
This provisions the XSUAA OAuth client and can take a few minutes.

![Subscription finalizing](assets/walkthrough/27-agent-subscription-finalizing.png)

### 4.3 Credentials available
Once finalized, the **Credentials** panel shows **Token URL**, **Key**, **Secret**.

![Credentials (masked)](assets/walkthrough/28-agent-subscription-credentials-masked.png)

> ⚠️ **Security:** the reveal (eye) button un-masks **all three at once** —
> there is no way to reveal Token URL/Key without also exposing the Secret.
> Copy the Secret straight into your terminal prompt; never paste it into a
> file, screenshot, or chat. Rotate/delete the subscription when done.

Captured (non-secret) for this run:
- **Token URL**: `https://<your-subdomain>.authentication.eu10.hana.ondemand.com/oauth/token`
- **Key (client_id)**: `<key-from-agent-subscription>
- **Secret**: *(entered interactively — not stored)*

---

## Phase 5 — MCP Server URL

**My Workspace → Subscriptions → Agents → blog Claude Code Agent → Products →
blog BTP Usage Reporting MCP → MCP Servers → blog_Resource_Consumption_mcpServer
→ Overview.**

- **MCP Server URL**: `https://<your-integration-cell-host>/blog-uas-reporting`
- **State**: ✅ ACTIVE
- **Authentication Provider**: ✅ Tenant XSUAA

![MCP Server URL — ACTIVE / Tenant XSUAA](assets/walkthrough/29-mcp-server-url-active.png)

---

## Phase 6 — Validate with curl

Config lives in a gitignored `.env` (see `.env.example` / `config.example`).
For this run:

```bash
IDENTITY_ZONE=<your-identity-zone>
VIRTUAL_HOST=<your-integration-cell-host>
MCP_PATH=blog-uas-reporting
AUTH_REGION=eu10
SAP_MCP_CLIENT_ID='<Key from the Agent Subscription>'
# SAP_MCP_CLIENT_SECRET intentionally omitted — test-mcp.sh prompts (read -s)
```

Run:
```bash
bash test-mcp.sh          # prompts for Client Secret only
# DRY_RUN=true bash test-mcp.sh   # verify URLs without credentials
```

A successful run: OAuth token obtained → `initialize` responds → `tools/list`
lists the MCP tools.

---

## Phase 7 — Connect Claude Code

```bash
claude mcp add \
  --transport http \
  --scope project \
  --client-id '<Key from the Agent Subscription>' \
  --client-secret \
  --callback-port 8080 \
  blog-uas-reporting \
  'https://<your-integration-cell-host>/blog-uas-reporting'
```

`--client-secret` with no value → Claude Code prompts interactively (kept out of
shell history). This writes `.mcp.json` (`--scope project`, no secrets in it).

Then: start Claude Code → `/mcp` → select `blog-uas-reporting` → complete the
OAuth flow in the browser.

---

## Security reminders

- Never commit `client_secret` or access tokens. `.env` and `.mcp.json` secrets stay local.
- The reveal button in Developer Hub un-masks all three credentials together — treat the whole panel as sensitive.
- Backend credentials (the Destination) are never exposed to the MCP client.
- Rotate the Agent Subscription secret / delete the blog objects after the walkthrough.
