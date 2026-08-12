#ifndef AMITY_SPS_INC_RESOLVER_TYPES
#define AMITY_SPS_INC_RESOLVER_TYPES

// Plug cell payload layout (SPS2). These are absolute cell pixel indices.
// Each resolved socket entry occupies 17 pixels:
//   POS X/Y/Z (3), FWD X/Y/Z (3), UP X/Y/Z (3), FLAGS (1), GUIDE (1),
//   TIN X/Y/Z (3), TOUT X/Y/Z (3) = 17.
// Rows 2-7 hold up to 5 entries (S1..S5). Entry 0 is the primary target.
#define SPS_PLUG_ENTRY_STRIDE 17
#define SPS_PLUG_ENTRY_START (AMITY_SPS_CELL_WIDTH * 1)
#define SPS_PLUG_MAX_ENTRIES 5

// Offsets within a single entry.
#define SPS_PLUG_ENTRY_POS 0
#define SPS_PLUG_ENTRY_FWD 3
#define SPS_PLUG_ENTRY_UP 6
#define SPS_PLUG_ENTRY_FLAGS 9
#define SPS_PLUG_ENTRY_GUIDE 10
#define SPS_PLUG_ENTRY_TIN 11
#define SPS_PLUG_ENTRY_TOUT 14

// Base pixel index of entry `i` (0-based).
#define SPS_PLUG_ENTRY_BASE(i) (SPS_PLUG_ENTRY_START + (i) * SPS_PLUG_ENTRY_STRIDE)

// Radius samples (16 values) live on row 15 (0-indexed row 14).
#define SPS_PLUG_RADIUS_SAMPLES_START (AMITY_SPS_CELL_WIDTH * 14)
#define SPS_PLUG_RADIUS_SAMPLE_COUNT 16

// Plug metadata row (R14 in the plug pixel map, 0-indexed row 13).
#define SPS_PLUG_META_ROW_BASE ((AMITY_SPS_CELL_HEIGHT - 3) * AMITY_SPS_CELL_WIDTH)
#define SPS_PLUG_META_R_INDEX (SPS_PLUG_META_ROW_BASE + 0)
#define SPS_PLUG_META_G_INDEX (SPS_PLUG_META_ROW_BASE + 1)
#define SPS_PLUG_META_B_INDEX (SPS_PLUG_META_ROW_BASE + 2)
#define SPS_PLUG_LENGTH_INDEX (SPS_PLUG_META_ROW_BASE + 3)
#define SPS_PLUG_RADIUS_INDEX (SPS_PLUG_META_ROW_BASE + 4)
#define SPS_PLUG_SOCK_PLAYER_INDEX (SPS_PLUG_META_ROW_BASE + 5)
#define SPS_PLUG_SOCK_ID_INDEX (SPS_PLUG_META_ROW_BASE + 6)
#define SPS_PLUG_SOCK_FRAC_INDEX (SPS_PLUG_META_ROW_BASE + 7)

#endif
