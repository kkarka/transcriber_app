import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.GitSCM
import hudson.plugins.git.UserRemoteConfig
import java.util.Collections

println "⚙️ Running Pipeline Job Init Script..."

def jenkins = Jenkins.getInstance()
def jobName = "transcriber-app-pipeline"

// 👇 CHANGE THIS TO YOUR ACTUAL GITHUB URL
def REPO_URL = "hhttps://github.com/kkarka/transcriber_app.git"

// Check if the job already exists to prevent overwriting
if (jenkins.getItem(jobName) == null) {
    println "🚀 Creating new Pipeline job: ${jobName}"
    
    // Create a standard Pipeline Job
    def job = jenkins.createProject(WorkflowJob.class, jobName)
    
    // Tell Jenkins to pull the code from Git
    def scm = new GitSCM(
        Collections.singletonList(new UserRemoteConfig(REPO_URL, null, null, null)),
        Collections.singletonList(new BranchSpec("*/main")),
        false, 
        Collections.emptyList(),
        null, null, null
    )
    
    // Tell Jenkins to look for the "Jenkinsfile" in that repo
    job.setDefinition(new CpsScmFlowDefinition(scm, "Jenkinsfile"))
    
    // Save the configuration
    job.save()
    jenkins.reload()
    
    println "✅ Pipeline job '${jobName}' created successfully targeting */main"
} else {
    println "ℹ️ Job '${jobName}' already exists. Skipping."
}