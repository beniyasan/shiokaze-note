# 96×128 style-master prototype

The approved 4×4 anime/chibi fisherman turnaround is a visual master only. This
local prototype converts each of the 16 source cells to a deterministic 96×128
native tile using a binary alpha cutoff, a compact median-cut palette, nearest
neighbour reduction and a shared local foot anchor at y=126. Soft generated
colour bleed is intentionally removed; no runtime texture or draw code changed.

Rows retain front, back, right-profile and left-profile facings. Columns retain
walk-frame timing/gear consistency from the source sheet. The hand-painted cues
are navy cap/hair, warm cream brim and scarf, teal jacket, orange trousers,
chunky brown boots, olive shoulder pack and a dark fishing rod/reel.

Runtime impact if adopted: atlas is 384×512 RGBA (768 KiB uncompressed), still
16 cells and 96×128 source regions. Existing 2× destination draw/collider and
feet anchor remain compatible. This branch/artifact is intentionally local-only
for visual review; PR20 remains untouched.
