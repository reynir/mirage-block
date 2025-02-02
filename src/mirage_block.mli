(*
 * Copyright (C) 2015-present David Scott <dave.scott@unikernel.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

(** Block device signatures. *)

type error = [ `Disconnected ]
(** The type for IO operation errors. *)

val pp_error: error Fmt.t
(** [pp_error] pretty-prints errors. *)

type write_error = [
  | error
  | `Is_read_only      (** attempted to write to a read-only disk *)
]

val pp_write_error: write_error Fmt.t
(** [pp_write_error] pretty-prints errors. *)

type info = {
  read_write: bool;    (** True if we can write, false if read/only *)
  sector_size: int;    (** Octets per sector *)
  size_sectors: int64; (** Total sectors per device *)
}
(** The type for characteristics of the block device. Note some
    devices may be able to make themselves bigger over time. *)

(** Operations on sector-addressible block devices, usually used for
    persistent storage. *)
module type S = sig

  type nonrec error = private [> error ]
  (** The type for block errors. *)

  val pp_error: error Fmt.t
  (** [pp_error] is the pretty-printer for errors. *)

  type nonrec write_error = private [> write_error ]
  (** The type for write errors. *)

  val pp_write_error: write_error Fmt.t
  (** [pp_write_error] is the pretty-printer for write errors. *)

  type t
  (** The type representing the internal state of the block device *)

  val disconnect: t -> unit Lwt.t
  (** Disconnect from the device. While this might take some time to
      complete, it can never result in an error. *)

  val get_info: t -> info Lwt.t
  (** Query the characteristics of a specific block device *)

  val read: t -> int64 -> Cstruct.t list -> (unit, error) result Lwt.t
  (** [read device sector_start buffers] reads data starting at
      [sector_start] from the block device into [buffers]. [Ok ()]
      means the buffers have been filled.  [Error _] indicates an I/O
      error has happened and some of the buffers may not be filled.
      Each of elements in the list [buffers] must be a whole number of
      sectors in length.  The list of buffers can be of any length. *)

  val write: t -> int64 -> Cstruct.t list ->
    (unit, write_error) result Lwt.t
  (** [write device sector_start buffers] writes data from [buffers]
      onto the block device starting at [sector_start]. [Ok ()] means
      the contents of the buffers have been written. [Error _]
      indicates a partial failure in which some of the writes may not
      have happened.

      Once submitted, it is not possible to cancel a request and there
      is no timeout.

      The operation may fail with: [`Is_read_only]: the device is read-only, no
      data has been written.

      Each of [buffers] must be a whole number of sectors in
      length. The list of buffers can be of any length.

      The data will not be copied, so the supplied buffers must not be
      re-used until the IO operation completes. *)

end
