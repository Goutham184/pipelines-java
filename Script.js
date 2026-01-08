const GITLAB_PROJECT_ID = "12345678"; // infra-deployments repo ID
const BRANCH = "main";
const TOKEN = ""; // injected via Pages env if needed

const headers = {
  "PRIVATE-TOKEN": TOKEN
};

async function fetchJSON(path) {
  const url =
    `https://gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID}` +
    `/repository/files/${encodeURIComponent(path)}` +
    `?ref=${BRANCH}`;

  const res = await fetch(url, { headers });
  const data = await res.json();
  return JSON.parse(atob(data.content));
}

async function loadDashboard() {
  const services = ["payments", "accounts"]; // static list (simple)

  const tbody = document.querySelector("#deployments tbody");

  for (const service of services) {
    for (const env of ["dev", "qa", "prod"]) {
      try {
        const data = await fetchJSON(`${service}/${env}.json`);

        const row = document.createElement("tr");
        row.innerHTML = `
          <td>${data.service}</td>
          <td>${data.environment}</td>
          <td>${data.image}</td>
          <td>${data.branch}</td>
          <td>
            <a href="https://gitlab.com/${data.service}/-/commit/${data.commit}">
              ${data.commit.substring(0, 8)}
            </a>
          </td>
          <td>
            <a href="${data.pipelineUrl}">
              #${data.pipelineId}
            </a>
          </td>
          <td>${data.deployedAt}</td>
        `;
        tbody.appendChild(row);
      } catch (e) {
        console.warn(`Missing ${service}/${env}`);
      }
    }
  }
}

loadDashboard();
