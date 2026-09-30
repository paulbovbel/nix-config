const searchInput = document.querySelector("#docs-search");
const moduleList = document.querySelector(".module-list");
const searchResults = document.querySelector("#search-results");
let searchIndex = [];

function updateCurrentLink() {
  const page = window.location.pathname.split("/").pop() || "index.html";
  const current = `${page}${window.location.hash}`;

  document.querySelectorAll(".sidebar a[aria-current]").forEach((link) => {
    link.removeAttribute("aria-current");
  });

  const sectionLink = [...document.querySelectorAll(".sidebar a")].find(
    (link) => link.getAttribute("href") === current,
  );
  const pageLink = [...document.querySelectorAll(".sidebar a")].find(
    (link) => link.getAttribute("href") === page,
  );
  (sectionLink || pageLink)?.setAttribute("aria-current", "page");
}

function addHeadingLinks() {
  document.querySelectorAll("main h2[id], main h3[id]").forEach((heading) => {
    const link = document.createElement("a");
    link.className = "heading-link";
    link.href = `#${heading.id}`;
    link.textContent = "#";
    link.setAttribute("aria-label", `Link to ${heading.textContent}`);
    heading.append(" ", link);
  });
}

function renderSearch() {
  const query = searchInput.value.trim().toLowerCase();
  searchResults.replaceChildren();
  moduleList.hidden = query.length > 0;
  searchResults.hidden = query.length === 0;

  if (!query) return;

  const matches = searchIndex
    .filter((entry) => entry.label.toLowerCase().includes(query))
    .slice(0, 30);
  for (const entry of matches) {
    const item = document.createElement("li");
    const link = document.createElement("a");
    link.href = entry.url;
    link.textContent = entry.label;
    const kind = document.createElement("small");
    kind.textContent = entry.kind;
    item.append(link, kind);
    searchResults.append(item);
  }
}

fetch("search.json")
  .then((response) => response.json())
  .then((entries) => {
    searchIndex = entries;
    searchInput.disabled = false;
  });

searchInput.addEventListener("input", renderSearch);
window.addEventListener("hashchange", updateCurrentLink);
addHeadingLinks();
updateCurrentLink();
