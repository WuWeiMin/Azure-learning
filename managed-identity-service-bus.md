<!-- 目标路径: notes/azure/managed-identity-service-bus.md -->

# Managed Identity with Azure Service Bus

## 1. What is Managed Identity

Managed Identity is an Azure feature that gives your application an **automatically managed identity in Azure AD (Entra ID)**.
Instead of storing a connection string or secret key in your code, Azure handles authentication for you.

| | Connection String | Managed Identity |
|---|---|---|
| Secret management | You manage the key, risk of leaking | Azure manages it automatically, no secret to leak |
| Code change | Key rotates → you must update code | No change needed, Azure handles rotation |
| Security | Key can be stolen if committed to GitHub | No key exists to steal |
| Suitable for | Quick demos, local testing | Production, enterprise environments |

## 2. System-assigned vs User-assigned

| | System-assigned | User-assigned |
|---|---|---|
| Lifecycle | Tied to the resource (deleted with it) | Independent, can be shared across resources |
| Use case | One resource needs one identity | Multiple resources share the same identity |
| Recommended for learning | ✅ Simpler to set up | Not needed for learning |

**For this learning guide, we use System-assigned Managed Identity.**

## 3. How it works (big picture)

```
Your App (with Managed Identity)
        ↓  "I am App X, I want to send a message"
   Azure AD (Entra ID)
        ↓  "App X is verified, here is a temporary token"
   Azure Service Bus
        ↓  "Token is valid, access granted"
   Message sent ✅
```

No connection string. No key. Azure handles the token exchange automatically.

## 4. The challenge for local development

Managed Identity only works when your code is **running inside Azure** (VM, App Service, Azure Function, Container, etc.).
When you run code locally on your company PC, there is no Managed Identity available.

**Solution: Use `DefaultAzureCredential`**

`DefaultAzureCredential` is a smart credential class from the Azure SDK that tries multiple authentication methods in order:
1. Environment variables
2. Workload Identity
3. Managed Identity (works when running inside Azure)
4. **Azure CLI login** ← this is what we use for local development
5. Visual Studio login
6. etc.

So for local testing, you just need to **log in with Azure CLI once**, and `DefaultAzureCredential` will pick it up automatically.

## 5. Setup steps

### Step 1: Install Azure CLI (if not already installed)
Download from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
Then log in:
```bash
az login
```
This opens a browser window. Log in with your Azure account (the same account as your personal Azure subscription).

### Step 2: Grant yourself the Service Bus role in Azure Portal

1. Go to Azure Portal → your Service Bus Namespace (`ken-learning-sb-std`)
2. Left menu → **Access control (IAM)**
3. Click **"+ Add"** → **"Add role assignment"**
4. Role: search and select **"Azure Service Bus Data Sender"** (for sending) or **"Azure Service Bus Data Owner"** (for both send and receive, easier for learning)
5. Assign access to: **User, group, or service principal**
6. Select: search for your own Azure account email → select it → Save

> For learning, assign **Azure Service Bus Data Owner** so you can both send and receive without adding two separate role assignments.

### Step 3: Update your code (see Section 6 below)

### Step 4 (future - when running inside Azure):
When your code runs on an Azure resource (e.g., Azure Function):
- Enable System-assigned Managed Identity on that resource
- Repeat Step 2, but this time assign the role to the **Managed Identity** of that resource instead of your personal account

## 6. C# code: Send message using DefaultAzureCredential

NuGet packages needed:
- `Azure.Messaging.ServiceBus`
- `Azure.Identity`

```csharp
// Target path: src/azure/ServiceBusManagedIdentitySenderDemo.cs
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using System;
using System.Threading.Tasks;

class ServiceBusManagedIdentitySenderDemo
{
    static async Task Main()
    {
        // Get the fully qualified namespace from:
        // Azure Portal -> Service Bus Namespace -> Overview -> "Host name" field
        // Format: <your-namespace>.servicebus.windows.net
        // Do NOT use the full connection string here - only the namespace hostname
        string fullyQualifiedNamespace = "<your-namespace>.servicebus.windows.net";
        string topicName = "order-events";

        // DefaultAzureCredential automatically uses:
        // - Managed Identity when running inside Azure
        // - Azure CLI login when running locally (after "az login")
        // No connection string or secret key needed
        var credential = new DefaultAzureCredential();

        var clientOptions = new ServiceBusClientOptions
        {
            TransportType = ServiceBusTransportType.AmqpWebSockets
        };

        ServiceBusClient client = new ServiceBusClient(fullyQualifiedNamespace, credential, clientOptions);
        ServiceBusSender sender = client.CreateSender(topicName);

        string messageBody = "Order #2001 created - sent via Managed Identity";
        ServiceBusMessage message = new ServiceBusMessage(messageBody);

        await sender.SendMessageAsync(message);
        Console.WriteLine($"Message sent via Managed Identity: {messageBody}");

        await sender.DisposeAsync();
        await client.DisposeAsync();
    }
}
```

## 7. C# code: Receive message using DefaultAzureCredential

```csharp
// Target path: src/azure/ServiceBusManagedIdentityReceiverDemo.cs
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using System;
using System.Threading.Tasks;

class ServiceBusManagedIdentityReceiverDemo
{
    static async Task Main()
    {
        // Get the fully qualified namespace from:
        // Azure Portal -> Service Bus Namespace -> Overview -> "Host name" field
        string fullyQualifiedNamespace = "<your-namespace>.servicebus.windows.net";
        string topicName = "order-events";
        string subscriptionName = "email-subscription";

        var credential = new DefaultAzureCredential();

        var clientOptions = new ServiceBusClientOptions
        {
            TransportType = ServiceBusTransportType.AmqpWebSockets
        };

        ServiceBusClient client = new ServiceBusClient(fullyQualifiedNamespace, credential, clientOptions);
        ServiceBusReceiver receiver = client.CreateReceiver(topicName, subscriptionName);

        ServiceBusReceivedMessage receivedMessage = await receiver.ReceiveMessageAsync();

        if (receivedMessage != null)
        {
            string body = receivedMessage.Body.ToString();
            Console.WriteLine($"[{subscriptionName}] Message received via Managed Identity: {body}");
            await receiver.CompleteMessageAsync(receivedMessage);
        }
        else
        {
            Console.WriteLine($"[{subscriptionName}] The subscription is empty; there are no messages.");
        }

        await receiver.DisposeAsync();
        await client.DisposeAsync();
    }
}
```

## 8. Key difference from connection string approach

| | Connection String | Managed Identity (DefaultAzureCredential) |
|---|---|---|
| Constructor | `new ServiceBusClient(connectionString)` | `new ServiceBusClient(fullyQualifiedNamespace, credential)` |
| What you provide | Full connection string (contains secret key) | Only the namespace hostname (no secret) |
| Auth handled by | You (must keep the key safe) | Azure SDK + Azure AD automatically |

## 9. How to find the fullyQualifiedNamespace

1. Azure Portal → your Service Bus Namespace
2. Left menu → **Overview**
3. Look for **"Host name"** field
4. It looks like: `ken-learning-sb-std.servicebus.windows.net`
5. Copy this value into your code

## 10. Next steps

- [ ] Run the demo locally using Azure CLI login (`az login`)
- [ ] Deploy code to an Azure Function and use real Managed Identity (System-assigned)
- [ ] Dead Letter Queue
- [ ] Dynamics 365 Plugin integration with Service Bus

---
*Note created: 2026-07-03*
