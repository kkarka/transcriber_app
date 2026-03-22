import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret

println "⚙️ Running Vault Credential Init Script..."

def store = SystemCredentialsProvider.getInstance().getStore()
def domain = Domain.global()

// Define the Vault Secret Text Credential (ID: 'root', Secret: 'root')
def vaultCred = new StringCredentialsImpl(
  CredentialsScope.GLOBAL,
  "root",                     
  "Automated Vault Root Token",    
  Secret.fromString("root")   
)

// Check if it already exists so we don't duplicate it
def existing = store.getCredentials(domain).find { it.id == vaultCred.id }
if (existing == null) {
    store.addCredentials(domain, vaultCred)
    println "✅ Successfully created Vault token credential with ID 'root'!"
} else {
    println "ℹ️ Vault token credential already exists. Skipping."
}