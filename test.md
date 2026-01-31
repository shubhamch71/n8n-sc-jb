Task: Make sources.json the Single Source of Truth for Companies                                                                                            
                                                                                                                                                                 
     Project Overview                                                                                                                                            
                                                                                                                                                                 
     This is an n8n job alerts system deployed on Fly.io that:                                                                                                   
     - Discovers DevOps/MLOps companies via Tavily + Gemini (weekly)                                                                                             
     - Scrapes jobs from company ATS pages (bi-hourly)                                                                                                           
     - Sends Telegram alerts for new jobs                                                                                                                        
     - Uses GitHub Actions for CI/CD                                                                                                                             
                                                                                                                                                                 
     Current Problem                                                                                                                                             
                                                                                                                                                                 
     Discovered companies are stored in n8n's internal staticData (SQLite on Fly.io volume).                                                                     
     If the volume is deleted, all discovered companies are LOST.                                                                                                
     They are not version controlled or backed up.                                                                                                               
                                                                                                                                                                 
     Solution: Option B - sources.json as Single Source of Truth                                                                                                 
                                                                                                                                                                 
     Make sources.json the ONLY place companies are stored:                                                                                                      
     1. Job discovery reads companies FROM sources.json (fetched from GitHub)                                                                                    
     2. Company discovery APPENDS new companies TO sources.json (commits to GitHub)                                                                              
     3. Manual companies and discovered companies both live in sources.json                                                                                      
     4. Everything is version controlled                                                                                                                         
                                                                                                                                                                 
     ---                                                                                                                                                         
     Repository Files                                                                                                                                            
                                                                                                                                                                 
     Key files to modify:                                                                                                                                        
     - /sources.json - Currently exists, needs new structure                                                                                                     
     - /job-alerts-workflow.json - Needs to read from GitHub instead of staticData                                                                               
     - /company-discovery-workflow.json - Needs to commit to GitHub instead of staticData                                                                        
     - /.env.example - Add GH_PAT variable                                                                                                                       
                                                                                                                                                                 
     Other files (don't modify unless necessary):                                                                                                                
     - /bot-commands-workflow.json                                                                                                                               
     - /health-monitor-workflow.json                                                                                                                             
     - /.github/workflows/deploy.yml                                                                                                                             
     - /.github/workflows/sync-secrets.yml                                                                                                                       
     - /fly.toml                                                                                                                                                 
     - /SETUP.md                                                                                                                                                 
     - /ARCHITECTURE.md                                                                                                                                          
                                                                                                                                                                 
     ---                                                                                                                                                         
     Implementation Details                                                                                                                                      
                                                                                                                                                                 
     Step 1: Update sources.json Structure                                                                                                                       
                                                                                                                                                                 
     Current structure:                                                                                                                                          
     [                                                                                                                                                           
       { "ats": "greenhouse", "board": "hashicorp", ... },                                                                                                       
       ...                                                                                                                                                       
     ]                                                                                                                                                           
                                                                                                                                                                 
     New structure:                                                                                                                                              
     {                                                                                                                                                           
       "version": "1.0",                                                                                                                                         
       "lastUpdated": "2026-01-31T00:00:00Z",                                                                                                                    
       "manual": [                                                                                                                                               
         { "ats": "greenhouse", "board": "hashicorp", "company": "HashiCorp", "enabled": true },                                                                 
         { "ats": "lever", "board": "figma", "company": "Figma", "enabled": true }                                                                               
       ],                                                                                                                                                        
       "discovered": [                                                                                                                                           
         { "ats": "lever", "board": "modal", "company": "Modal", "discovered_at": "2026-01-31", "category": "AI Infrastructure", "enabled": true }               
       ]                                                                                                                                                         
     }                                                                                                                                                           
                                                                                                                                                                 
     Step 2: Modify job-alerts-workflow.json                                                                                                                     
                                                                                                                                                                 
     In the "Load Source Configuration" node, change from reading staticData to:                                                                                 
                                                                                                                                                                 
     // Fetch sources.json from GitHub raw URL                                                                                                                   
     const repoOwner = 'YOUR_GITHUB_USERNAME';                                                                                                                   
     const repoName = 'n8n';                                                                                                                                     
     const branch = 'main';                                                                                                                                      
     const url = `https://raw.githubusercontent.com/${repoOwner}/${repoName}/${branch}/sources.json`;                                                            
                                                                                                                                                                 
     // Or use environment variable for the URL                                                                                                                  
     const sourcesUrl = $env.SOURCES_JSON_URL || url;                                                                                                            
                                                                                                                                                                 
     // Fetch and parse                                                                                                                                          
     const response = await fetch(sourcesUrl);                                                                                                                   
     const sourcesData = await response.json();                                                                                                                  
                                                                                                                                                                 
     // Merge manual + discovered                                                                                                                                
     const allSources = [...sourcesData.manual, ...sourcesData.discovered];                                                                                      
     const enabledSources = allSources.filter(s => s.enabled !== false);                                                                                         
                                                                                                                                                                 
     Note: n8n Code nodes can use $http.request() for HTTP calls.                                                                                                
                                                                                                                                                                 
     Step 3: Modify company-discovery-workflow.json                                                                                                              
                                                                                                                                                                 
     After the "Deduplicate & Store" node, add nodes to:                                                                                                         
                                                                                                                                                                 
     1. Fetch current sources.json from GitHub API                                                                                                               
     // GET /repos/{owner}/{repo}/contents/sources.json                                                                                                          
     // Returns file content (base64) and sha (needed for update)                                                                                                
                                                                                                                                                                 
     2. Append new companies to discovered array                                                                                                                 
     const currentSources = JSON.parse(atob(response.content));                                                                                                  
     currentSources.discovered.push(...newCompanies);                                                                                                            
     currentSources.lastUpdated = new Date().toISOString();                                                                                                      
                                                                                                                                                                 
     3. Commit updated file via GitHub API                                                                                                                       
     // PUT /repos/{owner}/{repo}/contents/sources.json                                                                                                          
     // Body: { message, content: base64(newContent), sha: currentSha }                                                                                          
     // Header: Authorization: Bearer $env.GH_PAT                                                                                                                
                                                                                                                                                                 
     Step 4: Add GitHub PAT Secret                                                                                                                               
                                                                                                                                                                 
     Need a GitHub Personal Access Token:                                                                                                                        
     1. GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens                                                                    
     2. Create token with:                                                                                                                                       
       - Repository access: Only select your n8n repo                                                                                                            
       - Permissions: Contents (Read and Write)                                                                                                                  
     3. Add to Fly.io: fly secrets set GH_PAT="ghp_xxxx"                                                                                                         
     4. Add to GitHub Actions secrets: GH_PAT                                                                                                                    
                                                                                                                                                                 
     Step 5: Update .env.example                                                                                                                                 
                                                                                                                                                                 
     Add:                                                                                                                                                        
     # GitHub Personal Access Token (for committing discovered companies)                                                                                        
     GH_PAT=ghp_your_personal_access_token                                                                                                                       
                                                                                                                                                                 
     # Sources JSON URL (optional, defaults to raw GitHub URL)                                                                                                   
     SOURCES_JSON_URL=https://raw.githubusercontent.com/USERNAME/n8n/main/sources.json                                                                           
                                                                                                                                                                 
     ---                                                                                                                                                         
     GitHub API Reference                                                                                                                                        
                                                                                                                                                                 
     Get file content:                                                                                                                                           
                                                                                                                                                                 
     GET https://api.github.com/repos/{owner}/{repo}/contents/sources.json                                                                                       
     Headers: Authorization: Bearer {token}                                                                                                                      
                                                                                                                                                                 
     Update file:                                                                                                                                                
                                                                                                                                                                 
     PUT https://api.github.com/repos/{owner}/{repo}/contents/sources.json                                                                                       
     Headers:                                                                                                                                                    
       Authorization: Bearer {token}                                                                                                                             
       Content-Type: application/json                                                                                                                            
     Body: {                                                                                                                                                     
       "message": "chore: add discovered companies",                                                                                                             
       "content": "{base64 encoded new content}",                                                                                                                
       "sha": "{sha from GET response}"                                                                                                                          
     }                                                                                                                                                           
                                                                                                                                                                 
     ---                                                                                                                                                         
     Architecture Diagram                                                                                                                                        
                                                                                                                                                                 
     ┌─────────────────────────────────────────────────────────────────┐                                                                                         
     │                        sources.json                              │                                                                                        
     │                      (GitHub - main branch)                      │                                                                                        
     │  ┌─────────────────────────────────────────────────────────┐    │                                                                                         
     │  │ { "manual": [...], "discovered": [...] }                │    │                                                                                         
     │  └─────────────────────────────────────────────────────────┘    │                                                                                         
     │            │                               ▲                     │                                                                                        
     │            │ (fetch raw)                   │ (commit via API)   │                                                                                         
     │            ▼                               │                     │                                                                                        
     │  ┌──────────────────┐           ┌──────────────────┐            │                                                                                         
     │  │ Job Discovery    │           │ Company Discovery │            │                                                                                        
     │  │ (every 2 hours)  │           │ (weekly)          │            │                                                                                        
     │  └──────────────────┘           └──────────────────┘            │                                                                                         
     └─────────────────────────────────────────────────────────────────┘                                                                                         
                                                                                                                                                                 
     ---                                                                                                                                                         
     Verification Steps                                                                                                                                          
                                                                                                                                                                 
     1. After implementation, manually run Company Discovery workflow                                                                                            
     2. Check GitHub - sources.json should have new entries in "discovered" array                                                                                
     3. Run Job Discovery - should scrape from both manual and discovered companies                                                                              
     4. Check git history - should see commit from n8n                                                                                                           
                                                                                                                                                                 
     ---                                                                                                                                                         
     Important Notes                                                                                                                                             
                                                                                                                                                                 
     - Keep existing staticData for other things (seen job hashes, API usage tracking)                                                                           
     - Only move COMPANY LIST to sources.json                                                                                                                    
     - Use GitHub raw URL for reading (no auth needed, faster)                                                                                                   
     - Use GitHub API for writing (needs GH_PAT)                                                                                                                 
     - Handle rate limits (GitHub API: 5000/hour with token)                                                                                                     
                                                                                                                                                                 
     Don't Break                                                                                                                                                 
                                                                                                                                                                 
     - Existing job scraping functionality                                                                                                                       
     - Deduplication of jobs (seenJobHashes in staticData - keep this)                                                                                           
     - Telegram notifications                                                                                                                                    
     - Health monitoring                                                                                                                                         
     - Kill switches                                                                                                                                             
                                                                          
