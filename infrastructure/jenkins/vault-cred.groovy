import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.datapipe.jenkins.vault.credentials.VaultTokenCredentialImpl 
import hudson.util.Secret

println "⚙️ Running Vault Token Credential Init Script..."

def store = SystemCredentialsProvider.getInstance().getStore()
def domain = Domain.global()

// Define the exact Vault Token Credential from your screenshot
// Parameters: Scope, ID, Description, Token
def vaultToken = new VaultTokenCredentialImpl(
    CredentialsScope.GLOBAL,
    "root", 
    "Automated Vault Root Token", 
    Secret.fromString("root")
)

// Check if it already exists to avoid duplicates
def existing = store.getCredentials(domain).find { it.id == vaultToken.id }

if (existing == null) {
    store.addCredentials(domain, vaultToken)
    println "✅ Successfully created 'Vault Token' credential with ID 'root'!"
} else {
    println "ℹ️ Vault Token credential 'root' already exists. Skipping."
}