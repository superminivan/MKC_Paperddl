<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { fetchCategories, fetchConferences } from "./services/api";
import { currentUser, loadCurrentUser, logout } from "./services/auth";
import type { Category, Conference, ConferenceQuery } from "./types/conference";
import ConferenceCard from "./components/ConferenceCard.vue";

const categories = ref<Category[]>([]);
const conferences = ref<Conference[]>([]);
const query = ref<ConferenceQuery>({
  sub: [] as string[],
  q: ""
});
const loading = ref(false);
const route = useRoute();
const router = useRouter();
const isHome = computed(() => route.name === "home");

function goAdmin() {
  router.push("/admin");
}

function goLogin() {
  router.push("/login");
}

function goHome() {
  router.push("/");
}

async function handleLogout() {
  await logout();
  router.push("/");
}

type RankValue = "any" | "A*" | "A" | "B" | "C" | "N";

const ccfRank = ref<Exclude<RankValue, "A*">>("any");
const coreRank = ref<RankValue>("any");
const thcplRank = ref<Exclude<RankValue, "A*">>("any");
const yearsSelected = ref<number[]>([]);

const availableYears = computed(() => {
  const years = new Set<number>();
  for (const conf of conferences.value) {
    const anyConf = conf as any;
    const y = Number(anyConf?.displayYear ?? conf.confs?.[0]?.year);
    if (Number.isFinite(y)) years.add(y);
  }
  return Array.from(years).sort((a, b) => b - a);
});

function getRank(conf: Conference, system: "ccf" | "core" | "thcpl"): string {
  const rank = conf.rank || ({} as any);
  if (system === "ccf") return (rank as any).ccf || "N";
  if (system === "core") return (rank as any).core || "N";
  return (rank as any).thcpl || (rank as any).thc || "N";
}

const ccfRankOptions = [
  { value: "any", label: "All" },
  { value: "A", label: "A" },
  { value: "B", label: "B" },
  { value: "C", label: "C" },
  { value: "N", label: "Non" }
] as const;

const coreRankOptions = [
  { value: "any", label: "All" },
  { value: "A*", label: "A*" },
  { value: "A", label: "A" },
  { value: "B", label: "B" },
  { value: "C", label: "C" },
  { value: "N", label: "Non" }
] as const;

const thcplRankOptions = [
  { value: "any", label: "All" },
  { value: "A", label: "A" },
  { value: "B", label: "B" },
  { value: "C", label: "C" },
  { value: "N", label: "Non" }
] as const;

const visibleConferences = computed(() => {
  const selectedYears = new Set(yearsSelected.value);
  return conferences.value.filter((conf) => {
    if (selectedYears.size) {
      const anyConf = conf as any;
      const year = Number(anyConf?.displayYear ?? conf.confs?.[0]?.year);
      if (!Number.isFinite(year) || !selectedYears.has(year)) return false;
    }

    if (ccfRank.value !== "any") {
      const value = getRank(conf, "ccf");
      if ((value || "N") !== ccfRank.value) return false;
    }

    if (coreRank.value !== "any") {
      const value = getRank(conf, "core");
      if ((value || "N") !== coreRank.value) return false;
    }

    if (thcplRank.value !== "any") {
      const value = getRank(conf, "thcpl");
      if ((value || "N") !== thcplRank.value) return false;
    }

    return true;
  });
});

const loadData = async () => {
  loading.value = true;
  try {
    const [cats, confs] = await Promise.all([
      fetchCategories(),
      fetchConferences(query.value)
    ]);
    categories.value = cats;
    const nowMs = Date.now();
    const parseConfDeadline = (conf: Conference) => {
      const candidate = conf.nextDeadline || conf.confs?.[0]?.timeline?.[0]?.deadline;
      if (!candidate || candidate.toUpperCase() === "TBD") return null;
      const parsed = Date.parse(candidate.replace(" ", "T"));
      return Number.isNaN(parsed) ? null : parsed;
    };
    const isExpired = (deadline: number | null) => {
      return deadline !== null && deadline <= nowMs;
    };
    const isUrgent = (deadline: number | null, expired: boolean) => {
      if (deadline === null || expired) return false;
      const diff = deadline - nowMs;
      return diff > 0 && diff < 24 * 60 * 60 * 1000;
    };
    const expandedConfs = confs.flatMap((conf) => {
      if (!conf.confs || conf.confs.length === 0) {
        return [conf];
      }
      return conf.confs.map((edition) => {
        const editionDeadline = edition.timeline?.[0]?.deadline || conf.nextDeadline;
        return {
          ...conf,
          confs: [edition],
          nextDeadline: editionDeadline,
          edition,
          displayYear: edition.year
        } as Conference;
      });
    });
    conferences.value = expandedConfs
      .slice()
      .sort((a: Conference, b: Conference) => {
        const aTime = parseConfDeadline(a);
        const bTime = parseConfDeadline(b);
        const aExpired = isExpired(aTime);
        const bExpired = isExpired(bTime);
        if (aExpired && !bExpired) return 1;
        if (!aExpired && bExpired) return -1;
        const aUrgent = isUrgent(aTime, aExpired);
        const bUrgent = isUrgent(bTime, bExpired);
        if (aUrgent && !bUrgent) return -1;
        if (!aUrgent && bUrgent) return 1;
        if (aTime === null && bTime === null) return 0;
        if (aTime === null) return 1;
        if (bTime === null) return -1;
        return aTime - bTime;
      });
  } catch (e) {
    console.error("Failed to fetch data:", e);
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  loadCurrentUser().catch(() => {
    // Auth state is optional on public pages.
  });
  loadData();
});

watch(query, () => {
    loadData();
}, { deep: true });

function handleSearch(e: Event) {
    const target = e.target as HTMLInputElement;
    query.value.q = target.value;
}

function toggleYear(year: number) {
  const set = new Set(yearsSelected.value);
  if (set.has(year)) set.delete(year);
  else set.add(year);
  yearsSelected.value = Array.from(set).sort((a, b) => b - a);
}
</script>

<template>
  <div class="container">
    <header class="hero">
      <div class="hero-main">
        <div class="hero-badge">CCF Deadlines</div>
        <h1>PaperDDL</h1>
      </div>
      <div class="hero-actions">
        <!-- <button
          v-if="isHome && currentUser"
          class="hero-nav-btn"
          type="button"
          @click="goAdmin"
        >
          后台管理
        </button> -->
        <button
          v-if="isHome && !currentUser"
          class="hero-nav-btn"
          type="button"
          @click="goLogin"
        >
          登录
        </button>
        <button
          v-else-if="!isHome && !currentUser"
          class="hero-nav-btn"
          type="button"
          @click="goHome"
        >
          返回
        </button>
        <button
          v-if="currentUser"
          class="hero-nav-btn"
          type="button"
          @click="handleLogout"
        >
          注销
        </button>
      </div>
    </header>

    <template v-if="isHome">
      <div class="toolbar-card">
        <div class="category-filter">
          <label v-for="cat in categories" :key="cat.sub" class="checkbox-label">
            <input type="checkbox" :value="cat.sub" v-model="query.sub" />
            {{ cat.name }}
          </label>
        </div>
        <div class="toolbar">
          <div class="search-box">
            <input type="text" :value="query.q" @input="handleSearch" placeholder="搜索会议..." />
          </div>
        </div>
        <div v-if="availableYears.length" class="year-rank-row">
          <div class="year-filter">
            <span class="filter-label">年份:</span>
            <label v-for="y in availableYears" :key="y" class="checkbox-label">
              <input type="checkbox" :checked="yearsSelected.includes(y)" @change="toggleYear(y)" />
              {{ y }}
            </label>
          </div>
          <div class="rank-grid compact" aria-label="Rank filters">
            <div class="filter-box compact">
              <div class="filter-title">CCF</div>
              <select v-model="ccfRank" aria-label="CCF rank">
                <option v-for="opt in ccfRankOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </option>
              </select>
            </div>
            <div class="filter-box compact">
              <div class="filter-title">CORE</div>
              <select v-model="coreRank" aria-label="CORE rank">
                <option v-for="opt in coreRankOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </option>
              </select>
            </div>
            <div class="filter-box compact">
              <div class="filter-title">THCPL</div>
              <select v-model="thcplRank" aria-label="THCPL rank">
                <option v-for="opt in thcplRankOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <div v-if="loading" class="loading">加载中...</div>
      <div v-else-if="visibleConferences.length === 0" class="empty">
        未找到相关会议。请尝试调整筛选条件或搜索关键词。
      </div>
      <div v-else class="grid">
        <ConferenceCard
          v-for="conf in visibleConferences"
          :key="`${conf.title}-${(conf as any).displayYear || conf.confs?.[0]?.year || ''}`"
          :conference="conf"
          :highlight="query.q || ''"
        />
      </div>
    </template>
    <RouterView v-else v-slot="{ Component }">
      <component :is="Component" @close="goHome" />
    </RouterView>
  </div>
</template>
