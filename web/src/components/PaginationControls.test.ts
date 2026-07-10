import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import PaginationControls from "@/components/PaginationControls.vue";
import { usePagination } from "@/composables/usePagination";
import { computed } from "vue";

function makePagination(itemCount: number, pageSize = 50) {
  const items = Array.from({ length: itemCount }, (_, i) => i);
  return usePagination(computed(() => items), { pageSize });
}

describe("PaginationControls", () => {
  it("shows count text with custom noun", () => {
    const pagination = makePagination(100);
    const wrapper = mount(PaginationControls, {
      props: { pagination, noun: "terms" },
    });
    expect(wrapper.text()).toContain("terms");
    expect(wrapper.text()).toContain("100");
  });

  it("shows page-size selector with 50/100/200/All buttons", () => {
    const pagination = makePagination(100);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    const sizerButtons = wrapper.findAll(".pagination-btn-mini");
    const labels = sizerButtons.map(b => b.text());
    expect(labels).toContain("50");
    expect(labels).toContain("100");
    expect(labels).toContain("200");
    expect(labels).toContain("All");
  });

  it("highlights active page size", () => {
    const pagination = makePagination(100);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    const activeBtn = wrapper.find(".pagination-btn-mini.pagination-btn-active");
    expect(activeBtn.text()).toBe("50");
  });

  it("highlights active page number", () => {
    const pagination = makePagination(500);
    pagination.setPage(3);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    const activeBtn = wrapper.find(".pagination-controls .pagination-btn-active");
    expect(activeBtn.text()).toBe("3");
  });

  it("shows ellipsis for large page counts", () => {
    const pagination = makePagination(500);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    expect(wrapper.find(".pagination-ellipsis").exists()).toBe(true);
  });

  it("does not show ellipsis for small page counts", () => {
    const pagination = makePagination(100);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    expect(wrapper.find(".pagination-ellipsis").exists()).toBe(false);
  });

  it("hides page navigation when All is selected", async () => {
    const pagination = makePagination(100);
    pagination.setPageSize("all");
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    expect(wrapper.find(".pagination-controls").exists()).toBe(false);
  });

  it("disables prev button on first page", () => {
    const pagination = makePagination(500);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    const navButtons = wrapper.findAll(".pagination-controls .pagination-btn");
    const prevBtn = navButtons[0];
    expect(prevBtn.attributes("disabled")).toBeDefined();
  });

  it("disables next button on last page", () => {
    const pagination = makePagination(100);
    pagination.setPage(pagination.pageCount.value);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    const navButtons = wrapper.findAll(".pagination-controls .pagination-btn");
    const nextBtn = navButtons.at(-1);
    expect(nextBtn?.attributes("disabled")).toBeDefined();
  });

  it("clicking a page button calls setPage", async () => {
    const pagination = makePagination(500);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    const pageBtn = wrapper.findAll(".pagination-controls .pagination-btn").find(b => b.text() === "2");
    await pageBtn?.trigger("click");
    expect(pagination.page.value).toBe(2);
  });

  it("clicking a page-size button calls setPageSize", async () => {
    const pagination = makePagination(500);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    const sizeBtn = wrapper.findAll(".pagination-btn-mini").find(b => b.text() === "100");
    await sizeBtn?.trigger("click");
    expect(pagination.pageSize.value).toBe(100);
  });

  it("renders nothing when total is 0", () => {
    const pagination = makePagination(0);
    const wrapper = mount(PaginationControls, {
      props: { pagination },
    });
    expect(wrapper.find(".pagination").exists()).toBe(false);
  });
});
