
import { describe, it, expect, beforeEach } from "vitest";

interface Job {
  client: string;
  title: string;
  description: string;
  budget: bigint;
  deadline: bigint;
  bidDeadline: bigint;
  status: string;
  assignedTo: string | null;
  createdAt: bigint;
}

interface Bid {
  amount: bigint;
  proposedTime: bigint;
  bidAt: bigint;
}

const mockContract = {
  admin: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  paused: false,
  jobCounter: 0n,
  jobs: new Map<bigint, Job>(),
  bids: new Map<string, Bid>(), // Key as `${jobId}-${bidder}`
  jobBidCount: new Map<bigint, bigint>(),
  MIN_BID_AMOUNT: 100n,
  currentBlock: 100n, // Mock block height

  isAdmin(caller: string) {
    return caller === this.admin;
  },

  isClient(jobId: bigint, caller: string) {
    const job = this.jobs.get(jobId);
    return job ? job.client === caller : false;
  },

  setPaused(caller: string, pause: boolean) {
    if (!this.isAdmin(caller)) return { error: 100 };
    this.paused = pause;
    return { value: pause };
  },

  createJob(
    caller: string,
    title: string,
    description: string,
    budget: bigint,
    deadline: bigint,
    bidDeadline: bigint
  ) {
    if (this.paused) return { error: 104 };
    if (title.length === 0 || description.length === 0) return { error: 101 };
    if (budget < this.MIN_BID_AMOUNT) return { error: 110 };
    if (deadline <= this.currentBlock || bidDeadline <= this.currentBlock || bidDeadline > deadline) return { error: 111 };
    const jobId = ++this.jobCounter;
    this.jobs.set(jobId, {
      client: caller,
      title,
      description,
      budget,
      deadline,
      bidDeadline,
      status: "open",
      assignedTo: null,
      createdAt: this.currentBlock,
    });
    this.jobBidCount.set(jobId, 0n);
    return { value: jobId };
  },

  placeBid(caller: string, jobId: bigint, amount: bigint, proposedTime: bigint) {
    if (this.paused) return { error: 104 };
    const job = this.jobs.get(jobId);
    if (!job) return { error: 102 };
    if (job.status !== "open") return { error: 109 };
    if (this.currentBlock > job.bidDeadline) return { error: 111 };
    if (amount < this.MIN_BID_AMOUNT || amount > job.budget) return { error: 106 };
    const bidKey = `${jobId}-${caller}`;
    if (this.bids.has(bidKey)) return { error: 107 };
    this.bids.set(bidKey, { amount, proposedTime, bidAt: this.currentBlock });
    const newCount = (this.jobBidCount.get(jobId) || 0n) + 1n;
    this.jobBidCount.set(jobId, newCount);
    if (newCount > 0n) {
      job.status = "bidding";
    }
    return { value: true };
  },

  acceptBid(caller: string, jobId: bigint, bidder: string) {
    if (this.paused) return { error: 104 };
    if (!this.isClient(jobId, caller)) return { error: 108 };
    const job = this.jobs.get(jobId);
    if (!job) return { error: 102 };
    if (job.status !== "open" && job.status !== "bidding") return { error: 103 };
    const bidKey = `${jobId}-${bidder}`;
    if (!this.bids.has(bidKey)) return { error: 102 };
    job.status = "assigned";
    job.assignedTo = bidder;
    return { value: true };
  },

  startProgress(caller: string, jobId: bigint) {
    if (this.paused) return { error: 104 };
    const job = this.jobs.get(jobId);
    if (!job) return { error: 102 };
    if (job.status !== "assigned") return { error: 103 };
    if (job.assignedTo !== caller) return { error: 100 };
    job.status = "in-progress";
    return { value: true };
  },

  markCompleted(caller: string, jobId: bigint) {
    if (this.paused) return { error: 104 };
    const job = this.jobs.get(jobId);
    if (!job) return { error: 102 };
    if (job.status !== "in-progress") return { error: 103 };
    if (caller !== job.client && caller !== job.assignedTo) return { error: 100 };
    if (this.currentBlock > job.deadline) return { error: 111 };
    job.status = "completed";
    return { value: true };
  },

  cancelJob(caller: string, jobId: bigint) {
    if (this.paused) return { error: 104 };
    if (!this.isClient(jobId, caller)) return { error: 108 };
    const job = this.jobs.get(jobId);
    if (!job) return { error: 102 };
    if (job.status !== "open" && job.status !== "bidding") return { error: 113 };
    job.status = "cancelled";
    return { value: true };
  },

  withdrawBid(caller: string, jobId: bigint) {
    if (this.paused) return { error: 104 };
    const job = this.jobs.get(jobId);
    if (!job) return { error: 102 };
    if (job.status !== "open" && job.status !== "bidding") return { error: 103 };
    const bidKey = `${jobId}-${caller}`;
    if (!this.bids.has(bidKey)) return { error: 102 };
    this.bids.delete(bidKey);
    const newCount = (this.jobBidCount.get(jobId) || 0n) - 1n;
    this.jobBidCount.set(jobId, newCount);
    if (newCount === 0n) {
      job.status = "open";
    }
    return { value: true };
  },

  markDisputed(caller: string, jobId: bigint) {
    if (this.paused) return { error: 104 };
    const job = this.jobs.get(jobId);
    if (!job) return { error: 102 };
    if (job.status !== "in-progress") return { error: 103 };
    if (caller !== job.client && caller !== job.assignedTo) return { error: 100 };
    job.status = "disputed";
    return { value: true };
  },
};

describe("DecoFreelance Job Posting Contract", () => {
  beforeEach(() => {
    mockContract.admin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.paused = false;
    mockContract.jobCounter = 0n;
    mockContract.jobs = new Map();
    mockContract.bids = new Map();
    mockContract.jobBidCount = new Map();
    mockContract.currentBlock = 100n;
  });

  it("should create a new job", () => {
    const result = mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    expect(result).toEqual({ value: 1n });
    const job = mockContract.jobs.get(1n);
    expect(job?.title).toBe("Web Development");
    expect(job?.status).toBe("open");
  });

  it("should prevent creating job with invalid details", () => {
    const result = mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "",
      "Build a website",
      1000n,
      200n,
      150n
    );
    expect(result).toEqual({ error: 101 });
  });

  it("should place a bid on a job", () => {
    mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    const result = mockContract.placeBid("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n, 800n, 10n);
    expect(result).toEqual({ value: true });
    const bid = mockContract.bids.get("1-ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21");
    expect(bid?.amount).toBe(800n);
    const job = mockContract.jobs.get(1n);
    expect(job?.status).toBe("bidding");
  });

  it("should prevent bidding on non-open job", () => {
    mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    mockContract.placeBid("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n, 800n, 10n);
    mockContract.acceptBid("ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5", 1n, "ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21");
    const result = mockContract.placeBid("ST4ABC...", 1n, 700n, 15n);
    expect(result).toEqual({ error: 109 });
  });

  it("should accept a bid", () => {
    mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    mockContract.placeBid("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n, 800n, 10n);
    const result = mockContract.acceptBid("ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5", 1n, "ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21");
    expect(result).toEqual({ value: true });
    const job = mockContract.jobs.get(1n);
    expect(job?.status).toBe("assigned");
    expect(job?.assignedTo).toBe("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21");
  });

  it("should start progress on assigned job", () => {
    mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    mockContract.placeBid("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n, 800n, 10n);
    mockContract.acceptBid("ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5", 1n, "ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21");
    const result = mockContract.startProgress("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n);
    expect(result).toEqual({ value: true });
    const job = mockContract.jobs.get(1n);
    expect(job?.status).toBe("in-progress");
  });

  it("should mark job as completed", () => {
    mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    mockContract.placeBid("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n, 800n, 10n);
    mockContract.acceptBid("ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5", 1n, "ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21");
    mockContract.startProgress("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n);
    const result = mockContract.markCompleted("ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5", 1n);
    expect(result).toEqual({ value: true });
    const job = mockContract.jobs.get(1n);
    expect(job?.status).toBe("completed");
  });

  it("should cancel a job", () => {
    mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    const result = mockContract.cancelJob("ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5", 1n);
    expect(result).toEqual({ value: true });
    const job = mockContract.jobs.get(1n);
    expect(job?.status).toBe("cancelled");
  });

  it("should withdraw a bid", () => {
    mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    mockContract.placeBid("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n, 800n, 10n);
    const result = mockContract.withdrawBid("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n);
    expect(result).toEqual({ value: true });
    const bid = mockContract.bids.get("1-ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21");
    expect(bid).toBeUndefined();
    const job = mockContract.jobs.get(1n);
    expect(job?.status).toBe("open");
  });

  it("should mark job as disputed", () => {
    mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    mockContract.placeBid("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n, 800n, 10n);
    mockContract.acceptBid("ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5", 1n, "ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21");
    mockContract.startProgress("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n);
    const result = mockContract.markDisputed("ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21X21", 1n);
    expect(result).toEqual({ value: true });
    const job = mockContract.jobs.get(1n);
    expect(job?.status).toBe("disputed");
  });

  it("should not allow actions when paused", () => {
    mockContract.setPaused(mockContract.admin, true);
    const result = mockContract.createJob(
      "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6EEG4GFD5C5",
      "Web Development",
      "Build a website",
      1000n,
      200n,
      150n
    );
    expect(result).toEqual({ error: 104 });
  });
});