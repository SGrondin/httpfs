using System;
using System.Net;
using System.Threading.Tasks;

using Httpfsc.Business.Http.FileSystem.Exceptions;
using Httpfsc.Business.Http.FileSystem.Results;

namespace Httpfsc.Business.Http
{
    public interface IHttpFileSystemProxy
    {
        #region Methods

        /// <summary>
        /// Get the contents of a directory.
        /// </summary>
        /// <param name="path">Remote relative path.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        /// <exception cref="NotADirectoryException"></exception>
        Task<ListDirectoryResult> ListDirectory(Url path, Action<HttpStatusCode, string> errorHandler);

        /// <summary>
        /// Download a file.
        /// </summary>
        /// <param name="path">Remote relative path of file to download.</param>
        /// <param name="to">Local absolute path to write the file.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        /// <exception cref="NotADirectoryException">Si path indique un répertoire.</exception>
        Task DownloadFile(Url path, Url to, Action<HttpStatusCode, string> errorHandler);

        /// <summary>
        /// Upload a file.
        /// </summary>
        /// <param name="to">Remote relative path to write the file.</param>
        /// <param name="file">Local absolute path of file to upload.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        Task UploadFile(Url to, string file, Action<HttpStatusCode, string> errorHandler);

        /// <summary>
        /// Create empty file.
        /// </summary>
        /// <param name="path">Remote relative path to write the file.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        Task CreateEmptyFile(Url path, Action<HttpStatusCode, string> errorHandler);

        /// <summary>
        /// Delete a file.
        /// </summary>
        /// <param name="path">Remote relative path of the file to be deleted.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        Task DeleteFile(Url path, Action<HttpStatusCode, string> errorHandler);

        /// <summary>
        /// Delete a directory.
        /// </summary>
        /// <param name="path">Remote relative path of the directory to be deleted.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        Task DeleteDirectory(Url path, Action<HttpStatusCode, string> errorHandler);

        /// <summary>
        /// Create a directory.
        /// </summary>
        /// <param name="path">Le chemin relatif distant du fichier à créer.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        Task CreateDirectory(Url path, Action<HttpStatusCode, string> errorHandler);

        #endregion
    }
}