/*
Copyright (C) 2017 Felipe Ferreira da Silva

This software is provided 'as-is', without any express or implied warranty. In
no event will the authors be held liable for any damages arising from the use of
this software.

Permission is granted to anyone to use this software for any purpose, including
commercial applications, and to alter it and redistribute it freely, subject to
the following restrictions:

  1. The origin of this software must not be misrepresented; you must not claim
	 that you wrote the original software. If you use this software in a
	 product, an acknowledgment in the product documentation would be
	 appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
	 misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/

using System;
using System.Interop;

namespace uastar;

public static class uastar
{
	const c_int PATH_FINDER_MAX_CELLS = 1024;

	public struct path_finder
	{
		public int32 cols;
		public int32 rows;
		public int32 start;
		public int32 end;
		public uint8 has_path;
		public uint8[PATH_FINDER_MAX_CELLS] state; /* Bit flags */
		public int32[PATH_FINDER_MAX_CELLS] parents;
		public int32[PATH_FINDER_MAX_CELLS] g_score;
		public int32[PATH_FINDER_MAX_CELLS] f_score;
		public function uint8(path_finder* path_finder, int32 col, int32 row) fill_func;
		public function int32(path_finder* path_finder, int32 col, int32 row, void* data) score_func;
		public void* data;
	}

	const uint8 PATH_FINDER_MASK_PASSABLE = 0x01;
	const uint8 PATH_FINDER_MASK_OPEN = 0x02;
	const uint8 PATH_FINDER_MASK_CLOSED = 0x04;
	const uint8 PATH_FINDER_MASK_PATH = 0x08;

	public static int32 path_finder_heuristic(path_finder* path_finder, int32 cell)
	{
		int32 cell_y;
		int32 cell_x;
		int32 end_y;
		int32 end_x;
		int32 dx;
		int32 dy;
		cell_y = cell / path_finder.cols;
		cell_x = cell - (cell_y * path_finder.cols);
		end_y = path_finder.end / path_finder.cols;
		end_x = path_finder.end - (end_y * path_finder.cols);
		if (cell_x > end_x)
		{
			dx = cell_x - end_x;
		} else
		{
			dx = end_x - cell_x;
		}
		if (cell_y > end_y)
		{
			dy = cell_y - end_y;
		} else
		{
			dy = end_y - cell_y;
		}
		return dx + dy;
	}

	public static uint8 path_finder_open_set_is_empty(path_finder* path_finder)
	{
		uint8 empty;
		int32 i;
		empty = 1;
		i = 0;
		while (i < path_finder.cols * path_finder.rows && empty == 1)
		{
			if ((path_finder.state[i] & PATH_FINDER_MASK_OPEN) == PATH_FINDER_MASK_OPEN)
			{
				empty = 0;
			}
			i = i + 1;
		}
		return empty;
	}

	public static int32 path_finder_lowest_in_open_set(path_finder* path_finder)
	{
		int32 lowest_f;
		int32 current_lowest;
		int32 count;
		int32 i;
		count = path_finder.cols * path_finder.rows;
		lowest_f = count;
		current_lowest = 0;
		i = 0;
		while (i < count)
		{
			if ((path_finder.state[i] & PATH_FINDER_MASK_OPEN) == PATH_FINDER_MASK_OPEN)
			{
				if (path_finder.f_score[i] < lowest_f)
				{
					lowest_f = path_finder.f_score[i];
					current_lowest = i;
				}
			}
			i = i + 1;
		}
		return current_lowest;
	}

	public static void path_finder_reconstruct_path(path_finder* path_finder)
	{
		int32 i;
		i = path_finder.end;
		while (i != path_finder.start)
		{
			if (path_finder.parents[i] != path_finder.start)
			{
				path_finder.state[path_finder.parents[i]] = path_finder.state[path_finder.parents[i]] | PATH_FINDER_MASK_PATH;
			}
			i = path_finder.parents[i];
		}
	}

	public static void path_finder_fill(path_finder* path_finder)
	{
		int32 row;
		row = 0;
		while (row < path_finder.rows)
		{
			int32 col;
			col = 0;
			while (col < path_finder.cols)
			{
				if (path_finder.fill_func(path_finder, col, row) == 1)
				{
					path_finder.state[row * path_finder.cols + col] = path_finder.state[row * path_finder.cols + col] | PATH_FINDER_MASK_PASSABLE;
				} else
				{
					path_finder.state[row * path_finder.cols + col] = path_finder.state[row * path_finder.cols + col] & ~PATH_FINDER_MASK_PASSABLE;
				}
				col = col + 1;
			}
			row = row + 1;
		}
	}

	public static void path_finder_begin(path_finder* path_finder)
	{
		path_finder.state[path_finder.start] = path_finder.state[path_finder.start] | PATH_FINDER_MASK_OPEN;
	}

	public static uint8 path_finder_find_step(path_finder* path_finder, void* data)
	{
		uint8 run;
		int32 current;
		int32 count;
		run = 1;
		current = 0;
		count = path_finder.cols * path_finder.rows;
		current = path_finder_lowest_in_open_set(path_finder);
		if (current == path_finder.end)
		{
			path_finder_reconstruct_path(path_finder);
			run = 0;
			path_finder.has_path = 1;
		} else if (path_finder_open_set_is_empty(path_finder) == 1)
		{
			run = 0;
			path_finder.has_path = 0;
		} else
		{
			int32[4] neighbors;
			int32 j;
			int32 tmp_g_score;
			path_finder.state[current] = path_finder.state[current] & ~PATH_FINDER_MASK_OPEN;
			path_finder.state[current] = path_finder.state[current] | PATH_FINDER_MASK_CLOSED;
			/* Left */
			if (current % path_finder.cols == 0)
			{
				neighbors[0] = -1;
			} else
			{
				neighbors[0] = current - 1;
			}
			/* Top */
			neighbors[1] = current - path_finder.cols;
			/* Right */
			if ((current + 1) % path_finder.cols == 0)
			{
				neighbors[2] = -1;
			} else
			{
				neighbors[2] = current + 1;
			}
			/* Bottom */
			neighbors[3] = current + path_finder.cols;
			/* Neighbors */
			tmp_g_score = 0;
			j = 0;
			while (j < 4)
			{
				int32 n;
				n = neighbors[j];
				if (n > -1 && n < count && (path_finder.state[n] & PATH_FINDER_MASK_CLOSED) == 0)
				{
					if ((path_finder.state[n] & PATH_FINDER_MASK_PASSABLE) == 0)
					{
						path_finder.state[n] = path_finder.state[n] | PATH_FINDER_MASK_CLOSED;
					} else
					{
						tmp_g_score = path_finder.g_score[current] + 1;
						if ((path_finder.state[n] & PATH_FINDER_MASK_OPEN) == 0 || tmp_g_score < path_finder.g_score[n])
						{
							path_finder.parents[n] = current;
							path_finder.g_score[n] = tmp_g_score;
							path_finder.f_score[n] = tmp_g_score + path_finder_heuristic(path_finder, n);
							if (path_finder.score_func != null)
							{
								path_finder.f_score[n] = path_finder.f_score[n] + path_finder.score_func(path_finder, n % path_finder.cols, n / path_finder.cols, data);
							}
							path_finder.state[n] = path_finder.state[n] | PATH_FINDER_MASK_OPEN;
						}
					}
				}
				j = j + 1;
			}
		}
		return run;
	}

	public static void path_finder_find(path_finder* path_finder, void* data)
	{
		path_finder_begin(path_finder);
		while (path_finder_find_step(path_finder, data) == 1)
		{
		}
	}

	public static int32 path_finder_get_heuristic_score(path_finder* path_finder, int32 col, int32 row)
	{
		return path_finder.f_score[row * path_finder.cols + col];
	}

	public static bool path_finder_is_passable(path_finder* path_finder, int32 col, int32 row)
	{
		return (path_finder.state[row * path_finder.cols + col] & PATH_FINDER_MASK_PASSABLE) == PATH_FINDER_MASK_PASSABLE;
	}

	public static bool path_finder_is_closed(path_finder* path_finder, int32 col, int32 row)
	{
		return (path_finder.state[row * path_finder.cols + col] & PATH_FINDER_MASK_CLOSED) == PATH_FINDER_MASK_CLOSED;
	}

	public static bool path_finder_is_open(path_finder* path_finder, int32 col, int32 row)
	{
		return (path_finder.state[row * path_finder.cols + col] & PATH_FINDER_MASK_OPEN) == PATH_FINDER_MASK_OPEN;
	}

	public static bool path_finder_is_path(path_finder* path_finder, int32 col, int32 row)
	{
		return (path_finder.state[row * path_finder.cols + col] & PATH_FINDER_MASK_PATH) == PATH_FINDER_MASK_PATH;
	}

	public static bool path_finder_is_start(path_finder* path_finder, int32 col, int32 row)
	{
		return row * path_finder.cols + col == path_finder.start;
	}

	public static bool path_finder_is_end(path_finder* path_finder, int32 col, int32 row)
	{
		return row * path_finder.cols + col == path_finder.end;
	}

	public static void path_finder_set_start(path_finder* path_finder, int32 col, int32 row)
	{
		path_finder.start = row * path_finder.cols + col;
	}

	public static void path_finder_set_end(path_finder* path_finder, int32 col, int32 row)
	{
		path_finder.end = row * path_finder.cols + col;
	}

	public static void path_finder_clear_path(path_finder* path_finder)
	{
		int32 i;
		i = 0;
		while (i < PATH_FINDER_MAX_CELLS)
		{
			path_finder.state[i] = path_finder.state[i] & ~(PATH_FINDER_MASK_OPEN | PATH_FINDER_MASK_CLOSED | PATH_FINDER_MASK_PATH);
			path_finder.parents[i] = 0;
			path_finder.g_score[i] = 0;
			path_finder.f_score[i] = 0;
			i = i + 1;
		}
		path_finder.has_path = 0;
	}

	public static void path_finder_initialize(path_finder* path_finder)
	{
		int32 i;
		i = 0;
		while (i < PATH_FINDER_MAX_CELLS)
		{
			path_finder.parents[i] = 0;
			path_finder.g_score[i] = 0;
			path_finder.f_score[i] = 0;
			path_finder.state[i] = PATH_FINDER_MASK_PASSABLE;
			i = i + 1;
		}
		path_finder.rows = 0;
		path_finder.cols = 0;
		path_finder.start = 0;
		path_finder.end = 0;
		path_finder.has_path = 0;
	}

}