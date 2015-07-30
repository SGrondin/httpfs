using System;
using System.Collections.Generic;
using System.Linq;

namespace Httpfsc.Business.Http.FileSystem.Results
{
    /// <summary>
    /// Result of a directory listing method.
    /// </summary>
    public class ListDirectoryResult
    {
        #region Constructors

        private ListDirectoryResult()
        {
            this.Folders = new List<Url>();
            this.Files = new List<Url>();
        }

        #endregion

        #region Properties

        /// <summary>
        /// List of folders contained in the directory.
        /// </summary>
        public IEnumerable<Url> Folders { get; private set; }

        /// <summary>
        /// List of files contained in the directory.
        /// </summary>
        public IEnumerable<Url> Files { get; private set; }

        #endregion

        #region Methods

        /// <summary>
        /// Create result from a response string.
        /// </summary>
        /// <param name="response">The <see cref="ListDirectoryResult"/>.</param>
        /// <returns></returns>
        public static ListDirectoryResult FromResponse(string response)
        {
            var splitResponse =
                response.Split(Environment.NewLine.ToCharArray()).Where(f => !string.IsNullOrWhiteSpace(f)).ToList();
            var folders = splitResponse.Where(f => f.EndsWith("/")).ToList();
            var files = splitResponse.Except(folders);

            var list = new ListDirectoryResult();
            list.Folders = folders.Select(f => new Url(f));
            list.Files = files.Select(f => new Url(f));

            return list;
        }

        /// <summary>
        /// Create result from scratch.
        /// </summary>
        /// <returns></returns>
        public static ListDirectoryResult FromEmptyResponse()
        {
            return new ListDirectoryResult();
        }

        #endregion
    }
}